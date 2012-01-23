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

    cps.each do |cp|
      work_queue.enqueue_b { make_pdf_for(cp, dirname) }
    end
    work_queue.join

    Rake::Task["clean".to_sym].invoke
    puts
    puts "Done."
    puts "You can print the forms using «rake forms:print»"
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

      c.course_profs.each do |cp|
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

