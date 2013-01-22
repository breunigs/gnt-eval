# encoding: utf-8

namespace :results do
  # This is a helper function that will create the result PDF file for a
  # given term and faculty_id in the specified directory.
  def evaluate(term_id, faculty_id, directory)
    f = Faculty.find(faculty_id)
    t = Term.find(term_id)

    puts "Could not find specified faculty (id = #{faculty_id})" if f.nil?
    puts "Could not find specified term (id = #{term_id})" if t.nil?
    return if f.nil? || t.nil?

    filename = f.longname.gsub(/\s+/,'_').gsub(/^\s|\s$/, "")
    filename << '_' << t.dir_friendly_title
    filename << '_' << (I18n.tainted? ? "mixed" : I18n.default_locale).to_s
    filename << '.tex'

    puts "Now evaluating #{filename}"
    File.open(directory + filename, 'w') do |h|
      h.puts(t.evaluate(f))
    end

    puts "Wrote #{directory+filename}"
    tex_to_pdf(directory+filename)
  end

  desc "fix common TeX errors and warn about possible ones"
  task :fix_tex_errors do
    courses = Term.currently_active.map { |s| s.courses }.flatten
    courses.each do |c|
      unless c.summary.nil?
        c.summary = c.summary.fix_common_tex_errors
        c.save

        warn = c.summary.warn_about_possible_tex_errors
        unless warn.empty?
            puts "Warnings for: #{c.title}"
            puts warn + "\n\n"
        end
      end

      c.tutors.each do |t|
        next if t.comment.nil?

        t.comment = t.comment.fix_common_tex_errors
        t.save

        warn = t.comment.warn_about_possible_tex_errors
        unless warn.empty?
            puts "Warnings for: #{c.title} / #{t.abbr_name}"
            puts warn + "\n\n"
        end
      end
    end
  end


  desc "find comment fields with broken LaTeX code"
  task :find_broken_comments do
    courses = Term.currently_active.map { |s| s.courses }.flatten
    @max = 0
    @cur = 0

    def tick
      @cur += 1
      print_progress(@cur, @max)
    end

    courses.each do |c|
      c.tutors.each do |t|
        next if t.comment.nil? || t.comment.empty?
        @max += 1
        work_queue.enqueue_b do
          unless test_tex_code(t.comment)
            puts "\rTeXing tutor  comments failed: #{c.title} / #{t.abbr_name}"
          end
          tick
        end
      end

      next if c.summary.nil? || c.summary.empty?
      @max += 1
      work_queue.enqueue_b do
        unless test_tex_code(c.summary)
            puts "\rTeXing course comments failed: #{c.title}"
        end
        tick
      end
    end
    work_queue.join
    puts "\nIf there were errors you might want to try"
    puts "\trake results:fix_tex_errors"
    puts "first before fixing manually."
  end

  def pdf_single(course)
    dirname = './tmp/results/singles/'
    FileUtils.mkdir_p(dirname)
    c = course
    filename = c.dir_friendly_title << '_' << c.term.dir_friendly_title << '.pdf'
    render_tex(c.evaluate(true), dirname + filename, false, false, true)
  end

  desc "create pdf report for a single course"
  task :pdf_single, [:course_id] => "forms:samples" do |t,a|
    course = Course.find(a.course_id) rescue nil
    if course.nil?
      warn "Course with ID=#{a.course_id} does not exist"
      next
    end
    pdf_single(course)
  end

  desc "create pdf reports for all courses of a faculty for a given term one at a time (i.e. a whole bunch of files). leave term_id and faculty_id empty for current term and all faculties."
  task :pdf_singles, [:term_id, :faculty_id] => "forms:samples" do |t,a|
    term_ids = a.term_id ? [a.term_id] : Term.currently_active.map(&:id)
    faculty_ids = a.faculty_id ? [a.faculty_id] : Faculty.find(:all).map(&:id)

    courses = Course.where(:term_id => term_ids, :faculty_id => faculty_ids)
    max = courses.map { |c| c.course_profs.size + c.tutors.size }.sum
    cur = 0
    print_progress(cur, max)
    courses.each do |course|
      work_queue.enqueue_b {
        pdf_single(course)
        cur += course.course_profs.size + course.tutors.size
        print_progress(cur, max, course.title)
      }
    end
    work_queue.join
  end

  desc "create report pdf file for a given term and faculty (leave empty for: lang = mixed, sem = current, fac = all)"
  task :pdf_report, [:lang_code, :term_id, :faculty_id] => "forms:samples" do |t, a|
    lang_code = a.lang_code || "mixed"
    dirname = './tmp/results/'
    FileUtils.mkdir_p(dirname)

    sem_ids = if a.term_id.nil?
      Term.currently_active.map { |s| s.id }
    else
      [a.term_id]
    end

    sem_ids.each do |sem_id|
      # we have been given a specific faculty, so evaluate it and exit.
      if not a.faculty_id.nil?
	I18n.default_locale = Seee::Config.settings[:default_locale]
	# taint I18n to get a mixed-language results file. Otherwise set
	# the locale that will be used
	if lang_code == "mixed"
	  I18n.taint
	else
	  I18n.untaint
	  I18n.default_locale = lang_code.to_sym
	  I18n.locale = lang_code.to_sym
	end
	I18n.load_path += Dir.glob(File.join(Rails.root, 'config/locales/*.yml'))
	evaluate(sem_id, a.faculty_id, dirname)
      else
	# no faculty specified, just find all and process them in parallel.
	Faculty.all.each do |f|
	  args = [lang_code, sem_id, f.id].join(",")
	  puts "Running «rake \"results:pdf_report[#{args}]\"»"
	  work_queue.enqueue_b { system("rake -s results:pdf_report[#{args}]") }
	end
	work_queue.join
      end
    end # sem_ids.each
    Rake::Task["results:make_preliminary".to_sym].invoke
  end

  desc "Creates preliminary versions of result files in tmp/results."
  task :make_preliminary do
    p = "./tmp/results"
    Dir.glob("#{p}/*.pdf") do |d|
      d = File.basename(d)
      next if d.match(/^preliminary_/)
      work_queue.enqueue_b do
        puts "Working on " + d
        `pdftk #{p}/#{d} background ./tools/wasserzeichen.pdf output #{p}/preliminary_#{d}`
      end
    end
    work_queue.join
    Rake::Task["clean".to_sym].invoke
  end
end
