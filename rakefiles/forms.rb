# encoding: utf-8

namespace :forms do
  desc "Create form samples for all available forms. Leave empty for current terms."
  task :samples, :semester_id do |t,a|
    forms = if a.semester_id.nil?
      Semester.currently_active.map { |s| s.forms }.flatten
    else
      Semester.find(a.semester_id).forms
    end

    forms.each do |f|
      f.languages.each do |l|
        work_queue.enqueue_b { make_sample_sheet(f, l) }
      end
    end
    work_queue.join
    Rake::Task["clean".to_sym].invoke
  end


  desc "(1) Generate the forms for each course and prof. Leave empty for current terms."
  task :generate, [:semester_id] do |t, a|
    dirname = './tmp/forms/'
    FileUtils.mkdir_p(dirname)

    cps = if a.semester_id.nil?
      Semester.currently_active.map { |s| s.course_profs }.flatten
    else
      Semester.find(a.semester_id).course_profs
    end

    prog = 0
    puts
    puts "Creating forms:"
    missing_students = []
    cps.each do |cp|
      #work_queue.enqueue_b do
        if cp.course.students.blank?
          missing_students << cp.course.title
        else
          make_pdf_for(cp, dirname)
        end
        prog += 1
        print_progress(prog, cps.size, cp.course.title)
     # end
    end
    work_queue.join

    unless missing_students.empty?
      warn "There are courses that don’t have their student count specified."
      warn missing_students.compact.join("\n")
      warn "No sheets were generated for these courses."
    end

    Rake::Task["forms:cover_sheets"].invoke(a.semester_id)
    Rake::Task["clean".to_sym].invoke
    puts
    puts "Checking if any form does not have two pages…"
    path = File.expand_path(GNT_ROOT + "/tmp/forms/*pcs.pdf")
    data = `#{GNT_ROOT}/tools/identify_pdfs_with_not_2_pages.rb #{path}`.strip
    if data.empty?
      puts "Done."
    else
      puts "The following forms do not have exactly two pages:"
      puts data
      puts
      puts "Please note that the software is currently not equipped to handle more than two pages properly."
    end
    puts
    puts "Done."
    puts "You can print the forms using «rake forms:print»"
    puts "But remember some forms have been omitted due to missing students count." if missing_students.any?
  end

  desc "Generate cover sheets that contain all available information about the lectures. Leave empty for current terms."
  task :cover_sheets, [:semester_id] do |t, a|
    require "#{GNT_ROOT}/tools/lsf_parser_base.rb"
    LSF.set_debug = false

    dirname = './tmp/forms/covers/'
    FileUtils.mkdir_p(dirname)

    puts "\n\n"
    puts "Please note: Although the covers contain the lecturer’s name"
    puts "they are only customized per lecture. If there are multiple"
    puts "lecturers the name of the last lecturer will be used (when"
    puts "sorted by fullname). This allows to print the cover page only"
    puts "once and have it printed on top of the last stack of that"
    puts "lecture."

    courses =  if a.semester_id.nil?
      Semester.currently_active.map { |s| s.courses }.flatten
    else
      Semester.find(a.semester_id).courses
    end

    prog = 0

    puts
    puts "Creating cover sheets:"
    courses.each do |c|
      work_queue.enqueue_b do
        cp = c.course_profs.sort_by { |cp| cp.get_filename }.last
        # probably should have language selector…
        tex = ERB.new(RT.load_tex("../form_cover")).result(binding)
        path = "#{dirname}cover #{cp.get_filename}.tex"
        File.open(path, 'w') {|f| f.write(tex) }
        xetex_to_pdf(path, true, true)
        prog += 1
        print_progress(prog, courses.size, c.title)
      end
    end
    work_queue.join
  end

  desc "(2) Print all #{"existing".bold} forms in tmp/forms. Uses local print by default."
  task :print => "misc:howtos" do
    system(Seee::Config.application_paths[:print])
  end


  desc "Generate checklist to see if everything has been printed and packed."
  task :checklist do
    puts "Rendering…"
    courses = Semester.currently_active.map { |s| s.courses }.flatten
    courses.sort! { |a,b| b.students <=> a.students }

    count = {}
    data = []
    courses.each do |c|
      desc = c.description.to_ascii.escape_for_tex

      # use the first to letters of the description to count how many
      # sheets there are for each day
      count[desc[0..1].gsub(/\\$/, "")] ||= 0
      count[desc[0..1].gsub(/\\$/, "")] += 1

      # this will create a seemingly random sort order in checklist.pdf
      # due to sorting by fullname although only surname is printed.
      c.course_profs.sort_by { |cp| cp.get_filename }.each do |cp|
        d = []
        d << desc[0..5]
        d << c.title.escape_for_tex[0..47]
        d << cp.prof.surname.escape_for_tex[0..20]
        data << d
      end
    end
    tex = ERB.new(RT.load_tex("../checklist")).result(binding)

    p = "#{GNT_ROOT}/tmp/checklist.pdf"
    render_tex(tex, p)
    puts "Opening in PDF viewer…"
    fork { exec "#{SCap[:pdf_viewer]} \"#{p}\"" }
  end

  desc "Creates required amount of copies #{"within".bold} a PDF file. This saves you from having to specify the amount of copies when printing each form manually."
  task :multiply do
    puts "Note: this is not required for local printing."
    puts "Files will be prependend with “ multiple_” (note the space)"
    system("./tools/multiply_pdfs.rb tmp")
  end

end

