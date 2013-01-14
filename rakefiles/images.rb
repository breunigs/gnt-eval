# encoding: utf-8

namespace :images do
  desc "(3) Run the scan script to import pages to #{simplify_path(SCfp[:scanned_pages_dir])}"
  task :scan do
    FileUtils.makedirs(SCfp[:scanned_pages_dir])
    Dir.chdir(SCfp[:scanned_pages_dir]) do
      system(SCc[:scan])
    end
    puts
    puts "Next recommended step: rake images:sortandalign"
  end

  desc "(4) Sort scanned images by barcode (#{simplify_path(SCfp[:scanned_pages_dir])} → #{simplify_path(SCfp[:sorted_pages_dir])})"
  task :sortandalign, :directory do |t, d|
    # use default directory if none given
    if d.directory.nil? || d.directory.empty?
      d = {}
      puts "No directory given, using default one: #{simplify_path(SCfp[:scanned_pages_dir])}"
      d[:directory] = SCfp[:scanned_pages_dir]
      FileUtils.makedirs(d[:directory])
    end

    # abort if the directory of choice does not exist for some reason
    if !File.directory?(d[:directory])
      puts "Given directory does not exist. Aborting."
    # actually sort the images
    else
      puts "Working directory is: #{d[:directory]}"
      files = Dir.glob(File.join(d[:directory], '*.tif'))
      sort_path = SCfp[:sorted_pages_dir]

      curr = 0
      threads = []

      files.each do |f|
        unless File.writable?(f)
          puts "No write access, cancelling."
          break
        end

        work_queue.enqueue_b do
          basename = File.basename(f, '.tif')
          zbar_result = find_barcode(f)
          barcode = (zbar_result.to_f / 10.0).floor.to_i
          # retry in case a non-existant barcode was found
          if zbar_result && (not CourseProf.exists?(barcode))
            zbar_result = find_barcode(f, true)
            barcode = (zbar_result.to_f / 10.0).floor.to_i
          end

          if zbar_result.nil? || (not CourseProf.exists?(barcode))
            puts "\nbizarre #{basename}: " + (zbar_result.nil? ? "Barcode not found" : "CourseProf (#{zbar_result}) does not exist")
            FileUtils.makedirs(File.join(sort_path, "bizarre"))
            FileUtils.move(f, File.join(sort_path, "bizarre"))
          else
            form = CourseProf.find(barcode).course.form.id.to_s + '_' +
              CourseProf.find(barcode).course.language.to_s

            FileUtils.makedirs(File.join(sort_path, form))
            FileUtils.move(f, File.join(sort_path, form, "#{barcode}_#{basename}.tif"))
          end

          curr += 1
          print_progress(curr, files.size)
        end
      end
      work_queue.join
      print_progress(curr, files.size)
      puts
      puts "Done!"
    end # else

    puts
    puts "Next recommended step: rake images:omr"
  end

  desc "(5) Evaluates all sheets in #{simplify_path(SCfp[:sorted_pages_dir])}"
  task :omr => 'images:getyamls' do
    # OMR needs the YAML files as TeX also outputs position information
    p = SCfp[:sorted_pages_dir]
    Dir.glob(File.join(p, "[0-9]*.yaml")).each do |f|
      next unless Dir.exist?(f[0..-6])
      puts "\n\n\nNow processing #{f}"
      bn = File.basename(f, ".yaml")
      system(%(./pest/omr2.rb -s "#{f}" -p "#{p}/#{bn}" -c #{number_of_processors}))
    end

    puts
    puts "Next recommended step: rake images:correct"
  end

  desc "Try to find empty sheets."
  task :find_empty_sheets do
    checks = 5
    puts "This simple heuristic checks if there are less than"
    puts "#{checks} checkmarks. If there are, the sheet is presented"
    puts "to you so you can decide to throw it out or not."
    all_sql = []
    tables = []
    Term.currently_active.map { |s| s.forms }.flatten.each do |form|
      tables << form.db_table
      sql = "SELECT path FROM #{form.db_table} WHERE #{checks} > (0 "
      form.questions.map do |q|
        next unless ["square", "tutor_table"].include?(q.type)
        if q.single?
          sql << "\n+ IF(#{q.db_column} > 0, 1, 0)"
        else
          q.db_column.each { |col| sql << "\n+ IF(#{col} > 0, 1, 0)" }
          sql << "\n+ IF(#{q.db_column.find_common_start+"noansw"} > 0, 1, 0)" if q.no_answer?
        end
      end
      sql << "\n)"
      all_sql << sql
    end
    paths = RT.custom_query(all_sql.join(" UNION ")).map { |row| row["path"] }
    tmp_path = "#{temp_dir}/is_this_sheet_empty.tif"
    paths.each do |p|
      FileUtils.ln_s(p, tmp_path, :force => true)
      fork { exec "#{SCap[:pdf_viewer]} \"#{tmp_path}\" 2>1 &> /dev/null" }
      puts "\n\n\n"
      puts "Image: #{p}"
      print "Delete sheet from disk and database? [y/N] "
      answ = STDIN.gets.strip.downcase
      next if answ == "n" or answ == ""
      redo if answ != "y"
      # delete sheet
      puts "Deleting in DB…"
      tables.each do |table|
        RT.custom_query_no_result("DELETE FROM #{table} WHERE path = ?", [p])
      end
      puts "From disk…"
      FileUtils.rm(p, :force => true) # try to delete, but don’t report errors
    end
    # cleanup
    FileUtils.rm(tmp_path, :force => true)
    puts "Done. All empty sheets have been removed."
  end

  desc "(6) Correct invalid sheets"
  task :correct do
    forms = Term.currently_active.map { |s| s.forms }.flatten
    tables = forms.collect { |form| form.db_table }
    system("./pest/fix.rb #{tables.join(" ")}")

    puts
    puts "Next recommended step: rake images:fill_text_box"
  end

  desc "(7) Fill in small text boxes (not comments)"
  task :fill_text_box do
    system("./pest/fill_text_box.rb")
    puts
    puts "Next recommended step: rake images:insertcomments"
  end

  desc "(8) make handwritten comments known to the web-UI (i.e. find JPGs in #{simplify_path(SCfp[:sorted_pages_dir])})"
  task :insertcomments do |t, d|
    cp = SCc[:cp_comment_image_directory]
    mkdir = SCc[:mkdir_comment_image_directory]

    Term.currently_active.each do |sem|
      system("#{mkdir} -p \"#{SCfp[:comment_images_public_dir]}/#{sem.dir_friendly_title}\"")
      path=File.join(File.dirname(__FILE__), "tmp/images")

      # find all existing images for courses/profs and tutors
      bcs = sem.barcodes
      cpics = CPic.where(:course_prof_id => bcs).map { |t| t.basename }
      tids = sem.courses.map { |c| c.tutors.map { |t| t.id } }
      tpics = Pic.where(:tutor_id => tids).map { |t| t.basename }

      # find all tables that include a tutor chooser
      forms = sem.forms.find_all { |form| form.include_question_type?("tutor_table") }
      tables = {}
      forms.each { |form| tables[form.db_table] = form.get_tutor_question.db_column }

      allfiles = Dir.glob(File.join(SCfp[:sorted_pages_dir], '**/*.jpg'))
      allfiles.each_with_index do |f, curr|
        bname = File.basename(f)
        next if bname =~ /_DEBUG/
        source = f.sub(/_[^_]+$/, "") + ".tif"
        barcode = find_barcode_from_path(f)

        if barcode == 0
          warn "\nCouldn’t detect barcode for #{bname}, skipping.\n"
          next
        end

        course_prof = CourseProf.find(barcode)
        if course_prof.nil?
          warn "\nCouldn’t find Course/Prof for barcode #{barcode} (image: #{bname}). Skipping.\n"
          next
        end

        p = nil
        # tutor comments, place them under each tutor
        if f.downcase.end_with?("_ucomment.jpg")
          # skip existing images
          next if tpics.include?(bname)
          # find tutor id
          tut_num = nil
          tables.each do |table, column|
            data = RT.custom_query("SELECT #{column} FROM #{table} WHERE path = ?", [source], true)
            tut_num = data[column].to_i if data
            break if tut_num
          end

          if tut_num.nil?
            warn "\n\nCouldn’t find any record in the results database for #{bname}. Cannot match tutor image. Skipping.\n"
            next
          end

          if tut_num == 0
            warn "\n\nCouldn’t add tutor image #{bname}, because no tutor was chosen (or marked invalid). Skipping.\n"
            next
          end

          # load tutors
          tutors = course_prof.course.tutors.sort { |a,b| a.id <=> b.id }

          if tut_num < 0
            warn "\n\nCouldn’t add tutor image #{bname}, because OMR result is ambigious. Have you run `rake images:correct`?"
            next
          end

          if tut_num > tutors.count
            warn "\n\nCouldn’t add tutor image #{bname}, because chosen tutor does not exist (checked field num > tutors.count). Skipping.\n"
            next
          end

          p = Pic.new
          p.tutor_id = tutors[tut_num-1].id
        else # files for the course/prof. Should be split up. FIXME.
          next if cpics.include?(bname)
          p = CPic.new
          p.course_prof = course_prof
        end
        p.basename = bname
        p.source = source
        # let rails know about this comment
        p.save
        # move comment to correct location
        `#{cp} #{f} #{File.join(SCfp[:comment_images_public_dir], sem.dir_friendly_title)}`
        print_progress(curr+1, allfiles.size)
      end # Dir glob
    end # Term.each

    puts
    puts "Done."
    puts
    puts "Next recommended step: Type all comments in the web interface."
    puts "After that, the commands in the “rake results:*” group should help you."
  end

  # find forms for current term and extract variables from the
  # first key that comes along. The language should exist for every
  # key, even though this is currently not enforced. Will be though,
  # once a graphical form creation interface exists.
  # Note: should be deprecated by forms:generate once we switch to
  # per CourseProf evaluation
  desc "Finds all different forms for each folder and saves the form file as #{simplify_path(SCfp[:sorted_pages_dir])}/[form id].yaml."
  task :getyamls do |t,o|
    `mkdir -p ./tmp/images`
    forms = Term.currently_active.map { |s| s.forms }.flatten
    forms.each do |form|
      form.abstract_form.lecturer_header.keys.collect do |lang|
        target = File.join(SCfp[:sorted_pages_dir], "#{form.id}_#{lang}.yaml")
        next if File.exists?(target)
        file = make_sample_sheet(form, lang)
        FileUtils.move("#{file}.yaml", target)
      end
    end
  end



end
