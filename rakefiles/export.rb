namespace :helper do
  desc "Export certain questions in CSV format, so they may be processed elsewhere"
  task :export, [:base64_data] => 'db:connect' do |t, a|
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
    Semester.find(:all).each do |s|
      puts "#{s.id}: #{s.title} #{s.now? ? "(current)" : ""}"
    end
    sems = get_or_fake_user_input(Semester.find(:all).collect{|x|x.id}, a[:sems])
    puts
    puts
    # collect some data which will be required later
    # stores which tables exist
    dbs = []
    # stores table name and form title (so the user can easily select
    # only certain types of forms).
    title = []
    # stores which table has which columns
    columns = {}
    # stores question text(s) for each column for selected tables
    ident = {}
    sems.each do |sem|
      sem = Semester.find_by_id(sem)
      dbs += sem.forms.collect { |f| f.db_table }.uniq
      title += sem.forms.collect { |f| "#{f.db_table} (#{f.name})" }.uniq
      sem.forms.each do |f|
        # collect which columns each table has
        columns[f.db_table] = f.questions.collect { |q| q.db_column }.flatten
      end
    end

    puts "======"
    puts "Tables"
    puts "======"
    puts "Choose which tables you want to export. Valid ones are:"
    puts title.join("\n")
    dbs = get_or_fake_user_input(dbs, a[:dbs])

    # only collect identifiers for tables that were selected
    Form.find(:all).select { |f| dbs.include?(f.db_table) }.each do |f|
      f.questions.each do |q|
        # also collect which question text each *identifier* has. They are
        # later put into a single table, so the user should be aware if a
        # label has multiple meanings.
        if q.db_column.is_a? Array
          # also collect answer text for multiple choice questions
          q.db_column.each_with_index do |c,i|
            ident[c] ||= []
            ident[c] << "#{q.text}   --   #{q.boxes[i].any_text}"
          end
        else
          ident[q.db_column] ||= []
          ident[q.db_column] << q.text
        end
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
    qry_stats = []
    header = nil
    export.each do |db,cols|
      extracols = allcols-export[db]
      # first subquery defines order of columns, so only write header
      # if not yet defined
      header ||= cols + extracols
      cols = cols + (extracols.collect {|x| "\"\" AS #{x}"})
      # note: the NULLIF command is used to exclude 0-valued columns from
      # the average calculation
      cols_stats = cols.collect { |x| "AVG(NULLIF(#{x}, 0)) as #{x}" } + (extracols.collect {|x| "\"\" AS #{x}"})
      # FIXME: Do not hardcode tutor_id as it may change
      qry << "SELECT barcode, tutor_id, path, '#{db}' AS tbl, #{cols.join(", ")} FROM #{db}"
      qry_stats << "SELECT barcode, '#{db}' as tbl, COUNT(*) as returned_sheets, #{cols_stats.join(", ")} FROM #{db} GROUP BY barcode"
    end
    qry = qry.join(" UNION ALL ")
    qry_stats = qry_stats.join(" UNION ALL ")
    # add the question text to each question header as well
    fullheader = header.collect { |h| h + ": " + ident[h].join(" // ") }
    header_stats = Array.new(fullheader)

    puts
    puts "================="
    puts "Further aggregate"
    puts "================="
    puts "You can further aggregate (average) the first n questions you"
    puts "chose above for the statistics file. Enter 0 if you do not want"
    puts "this additional column, enter 2 to average the average of the"
    puts "first two questions. If you think the average of an average"
    puts "is kind of dumb, then you are a good person. It’s included"
    puts "because some people thought up the \"LQI\"; you can find some"
    puts "info about it here: http://www.kit.edu/visit/pi_2010_2933.php"
    lqi = get_or_fake_user_input((0..header.size).to_a, [a[:lqi].to_s]).first.to_i

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
      line += d
      lines << line
    end

    # write data to CSV
    `mkdir -p "tmp/export"`
    now = Time.now.strftime("%Y-%m-%d %H:%M")
    file = "tmp/export/#{now} #{header.join(" ")}.csv"
    puts "Writing CSV"
    opt = {:headers => true, :write_headers => true}
    FasterCSV.open(file, "wb", opt) do |csv|
      csv << fullheader.to_a
      lines.each { |l| csv << l }
    end

    # STATISTICS #######################################################

    puts
    puts "Running stats query: " + qry_stats
    data = RT.custom_query(qry_stats)
    lines = []

    # add metadata to stats (predefined)
    data.each_with_index do |d,i|
      barcode, table, returned_sheets = *d.shift(3)
      cp = CourseProf.find_by_id(barcode)
      line = []
      line << cp.course.form.name
      line << barcode
      line << cp.prof.fullname
      line << cp.course.title
      line << cp.course.students
      line << returned_sheets
      line << (d[0..lqi].sum.to_f/lqi.to_f) if lqi > 0

      line += d
      lines << line
    end

    file_stats = "tmp/export/#{now} #{header.join(" ")} Statistics.csv"
    puts "Writing statistics CSV"
    FasterCSV.open(file_stats, "wb", opt) do |csv|
      csv << ["questionnaire", "unique id (lecture+prof+semester)", "prof",   \
                  "lecture", "expected students", "returned sheets"]          \
              + (lqi > 0 ? ["lqi (average of the next #{lqi} columns)"] : []) \
              + header_stats.to_a
      lines.each { |l| csv << l }
    end


    puts
    puts
    puts "============"
    puts "CVS exported"
    puts "============"
    puts "Done, have a look at " + "\"#{file}\"".bold
    puts
    puts "Some stats about the exported data/lectures has been written to:"
    puts "\"#{file_stats}\""
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

    data = {:sems => sems, :dbs => dbs, :cols => export, :meta => meta_store, :lqi => lqi}
    # base64 encode the data to avoid having to deal with non-printable
    # chars produced by Marshal, spaces, commas, etc.
    print "rake \"helper:export["
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
