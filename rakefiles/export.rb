# encoding: utf-8

namespace :results do
  # accepts array of term IDs and returns array of valid forms for
  # that term
  def get_forms_for_terms(terms)
    forms = terms.collect { |s| Term.find_by_id(s).forms }.flatten
    forms.select { |f| f.abstract_form_valid? }
  end

  # accepts array of forms or form IDs and returns hash in the format of
  # { db_table => Name of Form }.
  def get_tables_for_forms(forms)
    forms.collect! { |f| f.is_a?(Form) ? f : Form.find_by_id(f) }
    Hash[forms.collect { |f| [f.db_table, f.name] }]
  end

  # gets the term(s) from the user, if it isn’t defined in the user
  # input or not valid. Exists if no term is chosen.
  def ask_term(user_input)
    print_head "Term"
    puts "Choose term to export:"
    Term.all.each do |s|
      puts "#{s.id}: #{s.title} #{s.now? ? "(current)" : ""}"
    end
    terms = get_or_fake_user_input(Term.all.collect{|x|x.id}, user_input)
    puts
    puts
    if terms.empty?
      puts "no term(s) chosen. Exiting."
      exit 0
    end
    terms
  end

  # Asks the user which faculties to include. Exits if no choice is
  # made. Automatically takes user_input if given and valid. Returns
  # actually Faculty instances (no IDs).
  def ask_faculty(user_input)
    print_head "Faculty"
    puts "Choose faculty to export:"
    Faculty.all.each do |f|
      puts "#{f.id}: #{f.shortname}"
    end
    faculty = get_or_fake_user_input(Faculty.all.collect{|x|x.id}, user_input)
    puts
    puts
    if faculty.empty?
      puts "no faculty chosen. Exiting."
      exit 0
    end
    faculty.map! { |f| Faculty.find_by_id(f) }
    faculty
  end

  # Adds the metadata given in meta to an array.
  def add_metadata(meta, barcode, path = "", table = "", tutnum = 0)
    cp = CourseProf.find_by_id(barcode)
    line = []
    meta.each do |m|
      case m
        when "path"       then line << path
        when "barcode"    then line << barcode
        when "table"      then line << table
        when "lecture"    then line << cp.course.title
        when "lang"       then line << cp.course.language
        when "sheet"      then line << cp.course.form.name
        when "term"       then line << cp.course.term.title
        when "prof"       then line << cp.prof.fullname
        when "profmail"   then line << cp.prof.email
        when "profgender" then line << cp.prof.gender.to_s[0..0]
        when "tutor"
          if tutnum-1 >=0 && tutnum-1 < cp.course.tutors.size
            line << cp.course.tutors[tutnum-1].abbr_name
          else
            line << ""
          end
      end
    end
    line
  end

  desc "Print list of tutors and user chosen fields"
  task :tutor_blacklist do |t, a|
    puts "This tool works on the assumption that two question asking"
    puts "the same thing also have the same db column. If that is not"
    puts "the case, you probably want to export one form at a time."
    puts
    faculty = ask_faculty(nil)
    faculty_barcodes = faculty.map { |f| f.barcodes }.flatten

    terms = ask_term(nil)
    # reject forms without tutors
    forms = get_forms_for_terms(terms).select { |f| f.get_tutor_question }

    # step one: find tutor questions for each form, only allow single
    fq = Hash[forms.collect do |f|
      [f, f.questions.select { |q| q.repeat_for == :tutor && q.single? }]
    end]
    # step two: only keep questions that are present in all forms
    # 2a: find columns for each form
    valid_cols = fq.values.map { |qs| qs.map { |q| q.db_column } }
    # 2b: intersect lists
    valid_cols = valid_cols.inject {|x, y| x & y }

    print_head "Columns"
    puts "Please choose columns to include:"
    valid_cols.each do |c|
      # print db column
      print c.ljust(30)
      # print question text. Since all questions should be the same, it
      # shouldn’t matter which question we choose…
      puts fq.values.first.detect { |q| q.db_column == c }.text
    end
    cols = get_or_fake_user_input(valid_cols, nil)
    if cols.empty?
      puts "No columns chosen. Exiting."
      exit 0
    end
    puts
    puts

    # helper function to exclude non-valid values from query; selects
    # both AVG and STDDEV for given column. Still not very nice because
    # only values from 1…98 are valid. However, this hack only excludes
    # -2, -1, 0 and 99.
    def vc(col)
      null = "NULLIF(NULLIF(NULLIF(NULLIF(#{col}, 99), 0), -1), -2)"
      "ROUND(AVG(#{null}), 1) AS #{col}_avg, " \
        + "ROUND(STDDEV(#{null}), 1) AS #{col}_stddev"
    end

    head = ["tutor", "#", *cols]
    head.map! { |h| h.gsub("_", " ") }
    data = []

    puts "Gathering data…"
    # now we have all required data, let’s build the query
    forms.each do |f|
      tutor_col = f.get_tutor_question.db_column
      bcs = faculty_barcodes & f.term.barcodes
      # outer query is only used for sorting by the sum of all AVGs to
      # give a rough sorting on 'awesomeness' of the tutor. Highly
      # doubtful, so please don’t tell anyone.
      qry = "SELECT * FROM ("
      qry << "SELECT barcode, #{tutor_col}, COUNT(*) AS count, "
      qry << cols.map { |c| vc(c) }.join(", ")
      qry << " FROM #{f.db_table}"
      # exclude invalid tutor ids: 0 == no choice made, 30 == "none"
      qry << " WHERE barcode IN (#{bcs.join(",")}) AND #{tutor_col} BETWEEN 1 AND 29"
      qry << " GROUP BY barcode, #{tutor_col}"
      qry << " HAVING COUNT(*) >= #{Seee::Config.settings[:minimum_sheets_required]}"
      qry << ") AS tbl ORDER BY #{cols.map{|c|"#{c}_avg"}.join("+")} ASC"
      data += RT.custom_query(qry)
    end
    # convert barcode + tutor id to tutor’s name
    data.map! do |d|
      d = d.values
      barcode, tutor_id, count = d.shift(3).map { |s| s.to_i }
      c = CourseProf.find_by_id(barcode)
      next if c.nil?
      t = c.course.tutors[tutor_id-1]
      next unless t && t.abbr_name
      # combine avg+stddev into one column
      [t.abbr_name, count, *d.each_slice(2).map {|x,y| "#{x} (#{y})"}]
    end
    # remove any entries we might have skipped
    data.compact!


    # Create PDF output on purpose because it’s hard to work with. These
    # are just some random numbers, so don’t work with them. Ever.
    puts "Rendering…"
    intro = ''
    intro << 'It\'s recommended to \emph{not} use this list. '
    intro << 'If you want to use this list for ranking, please visit your nearest suicide booth immediately. '
    intro << '\# counts handed in sheets; ignores abstentions and invalid answers. Therefore \# is only a rough indicator of how valid the next columns are. '
    intro << 'Columns are in the format AVG (STDDEV) over the position of the checkbox. The leftmost checkbox is encoded with 1. '
    intro << 'Assuming all leftmost boxes relate to “good”, then low AVGs indicate good tutors. '
    intro << 'The list is sort of sorted. '

    landscape = true
    table_height = 1.5
    margin = [1, 1, 1, 0]
    align = "lr"+"l"*cols.size
    # + data + head for:
    tex = ERB.new(RT.load_tex("../table")).result(binding)
    now = Time.now.strftime("%Y-%m-%d %H:%M")
    render_tex(tex, File.join(GNT_ROOT, "tmp/export/#{now} tutor export.pdf"), true, true)
  end


  desc "Export certain questions in CSV format, so they may be processed elsewhere"
  task :export, [:base64_data] do |t, a|
    PRECISION = 2

    # we now have gathered all necessary data to process the input. To
    # allow the user to execute a query multiple times, we
    require "rubygems"
    require "base64"
    # restore data if available
    a = a.base64_data.nil? ? {} : Marshal.load(Base64.decode64(a.base64_data))
    puts "====="
    puts "Howto"
    puts "====="
    puts "This is an interactive command, so you don't have to build"
    puts "a command line. It will print a command you can use later"
    puts "though, if you have to use this multiple times."
    puts
    puts "You can also try to build your own line, however that requires"
    puts "much effort and is error prone. If you do, good luck."
    puts
    puts "NOTE: Data will be exported depending on selected database"
    puts "tables. The term selector is just a convenience function"
    puts "so you don't have to choose between many tables. Then again,"
    puts "if you put more than one term in a single table you have"
    puts "graver problems anyway…"
    puts
    puts "Be aware that ALL data will be exported. It’s up to you to"
    puts "protect the participant’s anonymity if applicable."
    puts
    puts

    # select faculty to export
    faculty = ask_faculty(a[:faculty])

    # select term to limit list of tables
    terms = ask_term(a[:terms])

    ## collect some data which will be required later
    # stores which tables exist
    dbs = []
    # stores table name and form title (so the user can easily select
    # only certain types of forms).
    title = []
    # stores which table has which columns
    columns = {}
    # and which columns also have text
    columns_text = {}
    # stores question text(s) for each column for selected tables
    ident = {}
    # stores if a certain DB has a tutor table as well as its name
    tutor_col = {}
    terms.each do |term|
      term = Term.find(term)
      dbs += term.forms.collect { |f| f.db_table }.uniq
      title += term.forms.collect do |f|
        "#{f.db_table} (#{f.name}, #{term.title})"
      end.uniq
      term.forms.each do |f|
        # collect which columns each table has
        columns[f.db_table] = f.questions.collect { |q| q.db_column }.flatten
        columns_text[f.db_table] = f.questions.collect do |q|
          q.last_is_textbox? ? q.db_column : nil
        end.compact
      end
    end

    puts "======"
    puts "Tables"
    puts "======"
    puts "Choose which tables you want to export. Valid ones are:"
    puts title.join("\n")
    dbs_sel = get_or_fake_user_input(dbs, a[:dbs])
    dbs = dbs_sel.any? ? dbs_sel : dbs

    columns.reject! { |db, cols| !dbs.include?(db) }
    columns_text.reject! { |db, cols| !dbs.include?(db) }

    # only allow columns that appear in all selected tables
    columns = columns.values.inject(:"&")
    columns_text = columns_text.values.inject(:"&")

    # only collect identifiers for tables that were selected
    forms = Form.all.select do |f|
      f.abstract_form_valid? && dbs.include?(f.db_table)
    end

    # find tables that have tutor column
    forms.each do |f|
      q = f.get_tutor_question
      next unless q
      tutor_col[f.db_table] = q.db_column
    end

    forms.collect { |f| f.questions }.flatten.each do |q|
      next unless (columns + columns_text).include?(q.db_column)
      # also collect which question text each *identifier* has. They are
      # later put into a single table, so the user should be aware if a
      # label has multiple meanings.
      if q.multi?
        # also collect answer text for multiple choice questions
        q.db_column.each_with_index do |c,i|
          ident[c] ||= []
          ident[c] << "#{q.text.strip_common_tex}   --   #{q.boxes[i].any_text}"
        end
      else
        ident[q.db_column] ||= []
        ident[q.db_column] << q.text.strip_common_tex
      end
    end

    puts
    puts "========="
    puts "Questions"
    puts "========="
    puts "Now select which questions you want to export. Only columns"
    puts "that appear in all tables may be exported."
    puts
    puts "NOTE: If a label appears twice it means that its meaning or"
    puts "      question text differs for the selected forms. You probably"
    puts "      don't want to select it then."
    puts
    ident.sort.each do |col, meaning|
      meaning.uniq!
      meaning.each { |m| puts "#{col.ljust(10)}: #{m}" }
    end
    puts
    export = {}

    puts
    puts "Select columns. Valid ones are:"
    puts columns.join(" ")
    export = get_or_fake_user_input(columns, a[:cols].nil? ? nil : a[:cols])
    # automatically add _text columns in the correct position
    all = export.map { |c| columns_text.include?(c) ? [c, "#{c}_text"] : c }
    all.flatten!

    facs_bcs = faculty.collect { |f| f.barcodes }.flatten
    terms_bcs = terms.collect { |t| Term.find(t).barcodes }.flatten
    valid_barcodes = facs_bcs & terms_bcs

    where = "WHERE barcode IN (#{valid_barcodes.join(",")})"

    qry = []
    columns = all.any? ? (", " + all.join(", ")) : ""
    dbs.each do |db|
      if tutor_col[db]
        qry << "SELECT barcode, #{tutor_col[db]}, path, '#{db}' AS tbl #{columns} FROM #{db} #{where}"
      else
        qry << "SELECT barcode, '0' AS tutor_id, path, '#{db}' AS tbl #{columns} FROM #{db} #{where}"
      end
    end
    qry = qry.join(" UNION ALL ")


    puts
    puts "======="
    puts "Expand?"
    puts "======="
    puts "Include question text in column header? [y/N]"
    puts "y = db_column+qtext      n = db_column"
    expand = get_or_fake_user_input(/^$|^[ny]$/i, a[:expand]).downcase
    expand = "n" if expand.empty?

    # add the question text to each question header as well, if desired
    header = export.clone
    fullheader = expand == "y" ? header.map { |h| h + ": " + ident[h].join(" // ") } : header.clone


    puts
    puts
    puts
    puts "========"
    puts "Metadata"
    puts "========"
    puts "Which of the following meta data do you want to include?"
    meta = { "path" => "(local) path to the processed image",
      "barcode" => "uniq id for this term+lecture+prof",
      "table" => "table where this sheet is stored",
      "lecture" => "name of the lecture",
      "sheet" => "name of the sheet used to evaluate this lecture",
      "lang" => "language of the form used",
      "prof" => "name of the prof to whom this sheet belongs",
      "profmail" => "e-mail adress of the lecturer",
      "profgender" => "gender of prof. m=male, f=female, o=other",
      "tutor" => "name of tutor, if available",
      "term" => "abbreviation of term",
      "NONE" => "If you don’t need any metadata, simply press enter." }
    meta.sort.each { |k,v| puts "#{k.ljust(10)}: #{v}" }
    meta = get_or_fake_user_input(meta.keys, a[:meta])
    meta_store = meta.clone
    meta = meta.reject { |m| m == "NONE" }


    # add meta data columns to header. Meta is now an array as given by
    # the user, so no sorting required
    meta.reverse_each do |m|
      header.unshift(m)
      fullheader.unshift(m)
    end

    puts
    puts "========="
    puts "Execution"
    puts "========="

    lines = []
    lines_stat = []

    puts "Running data query… "# + qry
    data = RT.custom_query(qry)

    # add metadata and beautify output for the data CSV
    data.each do |d|
      line = add_metadata(meta, d["barcode"], d["path"], d["tbl"], d["tutor_id"])

      form = forms.find { |f| f.db_table == d["tbl"] }
      export.each_with_index do |col, ind|
        question = form.get_question(col)
        next unless question # will fail for _text questions
        boxes = question.boxes
        val = d[question.db_column]
        if boxes.any? { |b| b.nil? || b.any_text.blank? }
          line << val || "ERROR 1"
        else
          # reduce count by one if the last one is a textbox to include
          # the text field instead of “others”
          cnt = question.last_is_textbox? ? boxes.count-1 : boxes.count
          line << case(val.to_i)
            when -2..0 then "."
            when 99 then "NOT SPECIFIED"
            when 1..cnt then boxes[val.to_i-1].any_text.strip_common_tex
            else (question.last_is_textbox? ? d[question.db_column + "_text"] : "ERROR 2")
          end
        end
      end
      lines << line
    end

    puts "Running statistics…\n"
    header_stat = meta.clone + ["returned sheets"]
    looped_once = false
    valid_barcodes.each do |bc|
      cp = CourseProf.find(bc)
      table = cp.form.db_table
      line = add_metadata(meta, bc)
      line << cp.returned_sheets
      export.each_with_index do |col, ind|
        question = cp.form.get_question(col)
        if question.last_is_textbox?
          unless looped_once
            warn "Skipping question #{col} for statistics since it’s"
            warn "partly free text (last field is textbox).\n"
          end
          next
        end
        histogram = RT.answer_histogram(table, question, bc)
        sc, sa, ss = RT.count_avg_stddev(table, col, {:barcode => bc})

        # sanity check the output
        msgs = []
        msgs << "AVG: #{sa}" if sa < 0 || sa > question.boxes.size
        msgs << "STDDEV: #{sa}" if ss > question.boxes.size/2.0
        tmpcnt = 0
        histogram.each do |hkey, hval|
          tmpcnt += hval.to_f
          msgs<< "Histogram value for #{hkey}: #{hval}" if hval.to_f > 100
        end
        # allow rounding errors >> eps
        msgs <<  "Histogram values don’t sum up to 100: #{tmpcnt}" unless tmpcnt.between?(99.9, 100.1)
        if msgs.any?
          warn "\nOdd values detected for:"
          warn "Course: #{cp.course.title}"
          warn "Prof:   #{cp.prof.fullname}"
          warn "Quest:  #{question.db_column}"
          warn msgs.join("\n")
        end

        hvals = histogram.values.map { |v| "#{v.to_f.round(PRECISION)}%" }
        line += ["", sa.round(PRECISION), ss.round(PRECISION)] + hvals
        unless looped_once
          header_stat += ["", "#{col} AVG", "#{col} STDDEV"]
          header_stat += histogram.keys.map { |k| "#{col}: #{k}" }
        end
      end
      looped_once = true
      lines_stat << line
    end

    # write data to CSV
    puts "Writing CSV"
    FileUtils.mkdir_p "tmp/export/"
    filename = Time.now.strftime("%Y-%m-%d %H:%M") + " "
    filename << faculty.map { |f| f.shortname }.join("+") + " "
    filename << terms.map { |f| Term.find(f).title }.join("+")
    filename = "tmp/export/" + filename.gsub(/[^a-z0-9.,;:\s_-]/i, "")

    file_data = filename + " data.csv"
    file_stat = filename + " stat.csv"
    opt = {:headers => true, :write_headers => true}
    CSV.open(file_data, "wb", opt) do |csv|
      csv << header
      lines.each { |l| csv << l }
    end
    CSV.open(file_stat, "wb", opt) do |csv|
      csv << header_stat
      lines_stat.each { |l| csv << l }
    end


    puts
    puts
    puts "============"
    puts "CSV exported"
    puts "============"
    puts "Done, have a look at " + %("#{file_data}").bold
    puts "Also, if you know what you are doing see #{file_stat}."
    puts
    `type ssconvert >/dev/null 2>&1`
    if $?.exitstatus == 0
      puts "Also generating XLSX versions of those CSV files."
      system(%(ssconvert "#{file_data}" "#{file_data[0..-4]}xlsx" > /dev/null))
      system(%(ssconvert "#{file_stat}" "#{file_stat[0..-4]}xlsx" > /dev/null))
    else
      puts "Install gnumeric (or more specifically ssconvert) if you want"
      puts "to have export output XLSX files as well."
    end
    puts
    puts
    puts "=============="
    puts "Automatization"
    puts "=============="
    puts "If you want to run this query in the future, you can use:"

    data = {:terms => terms, :dbs => dbs, :cols => export, :expand => expand,
              :meta => meta_store, :faculty => faculty.map { |f| f.id }}
    # base64 encode the data to avoid having to deal with non-printable
    # chars produced by Marshal, spaces, commas, etc.
    print %(rake "results:export[)
    print Base64.encode64(Marshal.dump(data)).gsub(/\s/, "")
    puts %(]")
    puts
    puts "If you want to automate this, you can build a hash similar"
    puts "to the following. You can omit data, which will then be asked"
    puts "at runtime. Base64.encode64(Marshal.dump(hash)).gsub(/\\s/, \"\") "
    puts "will give you the data you can pass to the export task."
    pp data
  end

  desc "If the output style of the export feature does not suit you, you can use this tool to remap values."
  task :remap_export_data do
    unless File.exists?("#{GNT_ROOT}/tmp/export/remap.txt")
      puts "Remap rule file does not exist in tmp/export/remap.txt."
      puts "If you need an example, have a look at doc/export_remap_example.txt"
      puts "Exiting."
      exit 0
    end

    rules = []
    File.foreach("#{GNT_ROOT}/tmp/export/remap.txt") do |rule|
      next if rule.strip.empty?
      r = rule.split("→", 3)
      next if r.any? { |x| x.nil? }
      rules << r.map { |x| x.strip }
    end

    puts "Reading CSVs…"
    # Convert contents directly while reading. The header converter is
    # required because otherwise it would turn them into symbols. Would
    # be superfluous if I knew how to directly write the CSV in one go.
    opt =  { :header_converters => lambda { |h| h },
      :converters => lambda { |field, field_info|
        h = field_info.header.to_s.gsub(/:.*$/, "").strip
        field = field.to_s
        rules.each do |r|
          next unless r[0] == h || r[0] == "*"
          if r[1].empty?
            field = r[2] if field.empty?
            next
          end
          field = r[2] if field == r[1]
        end
        field
      }
    }
    csvs = {}
    Dir.glob("#{GNT_ROOT}/tmp/export/*.csv") do |d|
      csvs[d] = CSV.table(d, opt)
    end
    if csvs.empty?
      puts "No CSV files found in tmp/export. Exiting."
      exit 0
    end

    puts "Writing to disk…"
    csvs.each { |path, csv_table|
      File.open(path, 'w') {|f| f.write(csv_table) }
    }

    `type ssconvert >/dev/null 2>&1`
    if $?.exitstatus == 0
      puts "Attempting to re-create the XLSX files from the modified CSV ones…"
      csvs.each { |path, csv_table|
        p = path[0..-4]
        next unless File.exist?(p + "xlsx")
        begin
          File.delete(p + "xlsx")
          system(%(ssconvert "#{p}csv" "#{p}xlsx" > /dev/null))
        rescue
          warn "Couldn’t re-create #{p}xlsx from the CSV. Consider it broken."
        end
      }
    end
  end
end
