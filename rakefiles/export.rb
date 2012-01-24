namespace :results do
  desc "Export certain questions in CSV format, so they may be processed elsewhere"
  task :export, [:base64_data] do |t, a|
    # we now have gathered all necessary data to process the input. To
    # allow the user to execute a query multiple times, we
    require 'helfer/faster_csv.rb'
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
    puts "tables. The semester selector is just a convenience function"
    puts "so you don't have to choose between many tables. Then again,"
    puts "if you put more than one semester in a single table you have"
    puts "graver problems anyway…"
    puts
    puts "Be aware that ALL data will be exported. It’s up to you to"
    puts "protect the participant’s anonymity if applicable."
    puts
    puts
    # select semester to limit list of tables
    puts "========"
    puts "Semester"
    puts "========"
    puts "Choose semester to export:"
    Semester.all.each do |s|
      puts "#{s.id}: #{s.title} #{s.now? ? "(current)" : ""}"
    end
    sems = get_or_fake_user_input(Semester.all.collect{|x|x.id}, a[:sems])
    puts
    puts
    if sems.empty?
      puts "no semester(s) chosen. Exiting."
      exit 0
    end
    # collect some data which will be required later
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
    sems.each do |sem|
      sem = Semester.find_by_id(sem)
      dbs += sem.forms.collect { |f| f.db_table }.uniq
      title += sem.forms.collect do |f|
        "#{f.db_table} (#{f.name}, #{sem.title})"
      end.uniq
      sem.forms.each do |f|
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
    dbs = get_or_fake_user_input(dbs, a[:dbs])

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
    puts "Now select which questions you want to export. You have to do"
    puts "this for each table. Here's a list of the meaning of each"
    puts "identifier."
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
    dbs.each do |db|
      puts
      puts "Select columns for #{db}. Valid ones are:"
      puts columns[db].join(" ")
      export[db] = get_or_fake_user_input(columns[db], a[:cols].nil? ? nil : a[:cols][db])
    end
    allcols = export.values.flatten.uniq


    qry = []
    header = nil
    export.each do |db,cols|
      extracols = allcols-export[db]
      # first subquery defines order of columns, so only write header
      # if not yet defined
      header ||= cols + extracols
      # automatically add _text columns
      cols.map! { |c| columns_text[db].include?(c) ? [c, "#{c}_text"] : c }
      cols.flatten!
      cols = cols + (extracols.collect {|x| "\"\" AS #{x}"})
      if tutor_col[db]
        qry << "SELECT barcode, #{tutor_col[db]}, path, '#{db}' AS tbl, #{cols.join(", ")} FROM #{db}"
      else
        qry << "SELECT barcode, '0' AS tutor_id, path, '#{db}' AS tbl, #{cols.join(", ")} FROM #{db}"
      end
    end
    qry = qry.join(" UNION ALL ")
    # add the question text to each question header as well
    fullheader = header.collect { |h| h + ": " + ident[h].join(" // ") }

    puts
    puts "========"
    puts "Metadata"
    puts "========"
    puts "Which of the following meta data do you want to include?"
    meta = { "path" => "(local) path to the processed image",
      "barcode" => "uniq id for this semester+lecture+prof",
      "table" => "table where this sheet is stored",
      "lecture" => "name of the lecture",
      "sheet" => "name of the sheet used to evaluate this lecture",
      "lang" => "language of the form used",
      "prof" => "name of the prof to whom this sheet belongs",
      "profmail" => "e-mail adress of the lecturer",
      "profgender" => "gender of prof. m=male, f=female, o=other",
      "tutor" => "name of tutor, if available",
      "semester" => "abbreviation of semester",
      "NONE" => "If you are absolutely sure you do not need any meta data" }
    meta.sort.each { |k,v| puts "#{k.ljust(10)}: #{v}" }
    meta = get_or_fake_user_input(meta.keys, a[:meta])
    meta_store = meta
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

    # WHOLE DATA #######################################################
    puts "Running query: " + qry
    data = RT.custom_query(qry)
    lines = []

    # add metadata
    data.each do |d|
      barcode, tutnum, path, table = *d.shift(4)
      cp = CourseProf.find_by_id(barcode)
      line = []
      meta.each do |m|
        case m
          when "path":       line << path
          when "barcode":    line << barcode
          when "table":      line << table
          when "lecture":    line << cp.course.title
          when "lang":       line << cp.course.language
          when "sheet":      line << cp.course.form.name
          when "semester":   line << cp.course.semester.title
          when "prof":       line << cp.prof.fullname
          when "profmail":   line << cp.prof.email
          when "profgender": line << cp.prof.gender.to_s[0..0]
          when "tutor":
            if tutnum-1 >=0 && tutnum-1 < cp.course.tutors.size
              line << cp.course.tutors[tutnum-1].abbr_name
            else
              line << ""
            end
        end
      end

      form = forms.find { |f| f.db_table == table }
      export[table].each_with_index do |col, ind|
        question = form.get_question(col)
        next unless question # will fail for _text questions
        boxes = question.boxes
        if boxes.any? { |b| b.any_text.nil? || b.any_text.empty? }
          line << d[ind]
        else
          line << case(d[ind])
            when -2..0: ""
            when 99: I18n.t(:no_answer)
            when 1..boxes.count: boxes[d[ind]-1].any_text.strip_common_tex
            else (question.last_is_textbox? ? d[ind+1] : "ERROR")
          end
        end
      end
      lines << line
    end

    # write data to CSV
    `mkdir -p "tmp/export"`
    now = Time.now.strftime("%Y-%m-%d %H:%M")
    file = "tmp/export/#{now}.csv"
    puts "Writing CSV"
    opt = {:headers => true, :write_headers => true}
    FasterCSV.open(file, "wb", opt) do |csv|
      csv << fullheader.to_a
      lines.each { |l| csv << l }
    end


    puts
    puts
    puts "============"
    puts "CSV exported"
    puts "============"
    puts "Done, have a look at " + "\"#{file}\"".bold
    puts
    puts "It’s recommended to not use this for anything, because it’s clearly"
    puts "a reduction to some random values that have no meaning."
    puts "The leftmost field is encoded as 1 and the count increases by one"
    puts "for each checkbox to the right. These values are averaged. Wrong"
    puts "answers, e.g. two answers checked or none at all are not included"
    puts "in the statistic. Adding a \"don’t know\" column for the user is"
    puts "planned, but not yet included in the sheets."
    puts
    puts
    puts "=============="
    puts "Automatization"
    puts "=============="
    puts "If you want to run this query in the future, you can use:"
    # remove any added _text columns
    export.each do |tbl, cols|
      export[tbl] -= columns_text[tbl].map { |ct| ct + "_text" }
    end

    data = {:sems => sems, :dbs => dbs, :cols => export, :meta => meta_store}
    # base64 encode the data to avoid having to deal with non-printable
    # chars produced by Marshal, spaces, commas, etc.
    print "rake \"results:export["
    print Base64.encode64(Marshal.dump(data)).gsub(/\s/, "")
    puts "\"]"
    puts
    puts "If you want to automate this, you can build a hash similar"
    puts "to the following. You can omit data, which will then be asked"
    puts "at runtime. Base64.encode64(Marshal.dump(hash)).gsub(/\\s/, \"\") "
    puts "will give you the data you can pass to the export task."
    pp data
  end
end
