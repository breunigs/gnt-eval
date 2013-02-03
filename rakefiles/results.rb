# encoding: utf-8

namespace :results do
  # This is a helper function that will create the result PDF file for a
  # given term and faculty_id in the specified directory.
  def evaluate(lang_code, term_id, faculty_id, censor)
    f = Faculty.find(faculty_id)
    t = Term.find(term_id)

    raise 'invalid lang code' unless lang_code.is_a?(Symbol)

    directory = './tmp/results/'
    FileUtils.mkdir_p(directory)

    puts "Could not find specified faculty (id = #{faculty_id})" if f.nil?
    puts "Could not find specified term (id = #{term_id})" if t.nil?
    return if f.nil? || t.nil?

    lang_code = t.is_single_language?(faculty_id) || lang_code
    if lang_code == :auto
      I18n.taint
    else
      I18n.untaint
      I18n.locale = I18n.default_locale = lang_code
    end

    filename = censor ? 'censor_' : ''
    filename << f.longname.gsub(/\s+/,'_').gsub(/^\s|\s$/, "")
    filename << '_' << t.dir_friendly_title
    filename << '_' << (I18n.tainted? ? "mixed" : I18n.default_locale).to_s
    filename << '.tex'

    puts "Now evaluating #{filename}"
    File.open(directory + filename, 'w') do |h|
      h.puts(t.evaluate(f, censor))
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
    puts "Evaluating #{course.title}"
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

  desc "creates a (partly) censored PDF. Accepts the same parameters as pdf_report."
  task :pdf_report_censor, [:lang_code, :term_id, :faculty_id] do |t, a|
    @censor = true
    puts "It’s very sad, that you need to call this commend, isn’t it?"
    Rake::Task["results:pdf_report".to_sym].invoke(a.lang_code, a.term_id, a.faculty_id)
  end

  desc "create report pdf file for a given term and faculty (leave empty for: lang = auto, term = current, fac = all)"
  task :pdf_report, [:lang_code, :term_id, :faculty_id] => "forms:samples" do |t, a|
    I18n.load_path += Dir.glob(File.join(Rails.root, 'config/locales/*.yml'))
    lang_code = a.lang_code || :auto
    @censor ||= false

    term_ids = a.term_id ? [a.term_id] : Term.currently_active.map(&:id)
    term_ids.each do |term_id|
      if a.faculty_id
	work_queue.enqueue_b {
	  evaluate(lang_code.to_sym, term_id, a.faculty_id, @censor)
	}
	next
      end
      Faculty.all.each do |f|
	      work_queue.enqueue_b {
          evaluate(lang_code.to_sym, term_id, f.id, @censor)
	      }
      end
    end
    work_queue.join

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
