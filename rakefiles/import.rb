require 'rubygems'
require 'date'

class String
  # convert “surname, firstname” to “firstname surname” and remove
  # titles
  def cleanup_name
    s = self.gsub(/\s+/, " ")
    [/^Dr\. /i, /^Priv\. Doz\. Dr\. /i, /^N\.N\./i, /^Prof\. Dr\. /i].each do |r|
      s.gsub!(r, '')
    end
    s.split(",").reverse.join(" ").compress_whitespace
  end

  # convert “surname, firstname” to “firstname surname” and remove
  # titles. Works in place.
  def cleanup_name!
    self.replace(self.cleanup_name)
  end

  # returns given text in UTF-8 encoding
  def utf8_enc(from = "ISO-8859-1")
    $iconv ||= {}
    $iconv[from] ||= Iconv.new('UTF-8', from)
    $iconv[from].iconv(self + ' ')[0..-2]
  end
end

class LaierCSV
  SKIP = ["mintmachen", "robotik labor", "www-auftrag", "dekanat", "bibliothek", "kurs"]

  def self.data
    require 'csv'
    data = {}
    Dir.glob(IMPORT_PATH + "*.csv") do |csv|\
      puts "Processing CSV #{simplify_path(csv)}"
      CSV.open(csv, 'r') do |row|
	next if row[0].nil? # lecture
	next if row[3].nil? || row[3].strip.empty? # column 'G' for 'genehmigt'

	t = row[0].strip.downcase
	next if SKIP.include?(t)

	# 8: Tutor 1st name
	# 7: Tutor last name
	tut = "#{row[8]} #{row[7]}".compress_whitespace
	next if tut.gsub(".", "") == "NN"

	data[row[0]] ||= { :title => row[0], :lecturer => row[11].strip,
			  :students => nil, :tutors => [] }
	data[row[0]][:tutors] << tut
      end
    end
    data.values
  end
end

class MuesliYAML
  def self.data
    data = []
    Dir.glob(IMPORT_PATH + "*.y*ml") do |x|
      puts "Processing YAML #{simplify_path(x)}"
      begin
	YAML::load(File.read(x)).each do |l|
	  tuts = l["tutors"].collect { |t| t.cleanup_name }
	  data << { :title => l["name"],
		    :lecturer => l["lecturer"].cleanup_name,
		    :students => l["student_count"],
		    :tutors => tuts }
	end
      rescue => e
	warn "#{x} does not appear to be a 'good' YML file for the task at hand. Skipping."
	warn "Error:"
	warn PP.pp(e, "")
	next
      end
    end # glob
    data
  end
end

class UebungenDotPhysik
  URL_BASE = "http://uebungen.physik.uni-heidelberg.de/uebungen"
  URL_LECTURE_LIST = "#{URL_BASE}/liste.php?lang=en"
  URL_READ_LECTURE = "#{URL_BASE}/liste.php?lang=en&vorl="

  # Gathers all data from uebungen.physik and returns them as array of
  # hashes.
  def self.data
    puts "Loading UebungenDotPhysik…"
    require 'mechanize'
    @@brows ||= WWW::Mechanize.new
    # Fix crappy charset detections. We can do this because we know what
    # encoding the page is in.
    WWW::Mechanize::Util::CODE_DIC[:SJIS] = "ISO-8859-1"
    WWW::Mechanize::Util::CODE_DIC[:EUC] = "ISO-8859-1"
    @@brows.read_timeout = 30

    ids = UebungenDotPhysik.find_lecture_ids
    ids.map { |id| UebungenDotPhysik.get_lecture_details(id) }
  end

  private

  # finds all available lecture IDs and returns them as Array
  def self.find_lecture_ids
    @@brows.get(URL_LECTURE_LIST) do |page|
      code = page.content.compress_whitespace
      reg  = code.scan(/<a href=\'liste\.php\?vorl=([0-9]+)\' title=\'authentification needed\' >&lt;show group list/)
      return reg.map { |r| r[0] }.compact
    end
  end

  # load details about an event
  def self.get_lecture_details(id)
    @@brows.get(URL_READ_LECTURE + id) do |page|
      code = page.content.compress_whitespace

      title = code[/<h2><b>(.*) \(.*\)<\/b><\/h2>/, 1]

      lect = code[/<span class=\'kleiner\'>Dozent: <\/span>(.*?) <span class=\'kleiner\'>/, 1]
      lect.cleanup_name! unless lect.nil?

      students = code[/<span class=\'rot\'>([0-9]+)<\/span> Participants/, 1]
      students = students.to_i == 0 ? nil : students.to_i

      tuts = code.scan(/<li><a href=\'teilnehmer\.php\?gid=[0-9]+\'><b>(?:.*?)<\/b><\/a> \((.*?)\) <br>/)
      tutors = tuts.map { |t| t[0].cleanup_name }.compact
      tutors.reject! { |t| t.empty? }

      return { :title => title, :lecturer => lect,
	      :students => students, :tutors => tutors }
    end
  end
end

namespace :misc do
  desc "Import and merge data from all over the place."
  task :import do
    # accepts list of names and tries to convert them into real “Prof”s
    # (the Rails Model)
    def names_to_profs(names, lsf_data)
      names.map do |l|
	name = l.split(" ")
	p = Prof.find_by_firstname_and_surname(name.first, name.last)
	next p if p
	# okay, so we couldn’t find a match in our database. Let’s see
	# if we can find it in lect.profs, so we can automatically add
	# him/her.
	puts "Couldn’t find Prof #{l} in our database. You now can:"
	puts "* Skip by typing “skip”. The prof will not be added."
	puts "* Look for him/her manually and give the Prof ID"
	p = lsf_data.profs.detect { |x| "#{x.first} #{x.last}" == l }
	action = if p && p.mail && !p.mail.empty?
	  puts "* Automatically add the prof with the following data by typing “add”:"
	  puts "    Firstname: #{p.first}"
	  puts "    Lastname:  #{p.last}"
	  puts "    Mail:      #{p.mail}"
	  gender = guess_gender(p.first)
	  # prefer female. If it’s wrong, everyone will believe it’s a
	  # data error and not call you sexist.
	  gender = :female if gender == :unknown
	  puts "    Gender:    #{gender} (guessed)"
	  puts "What do you want to do?"
	  get_user_input(/^[1-9][0-9]*|add|skip$/, true)
	else # cannot automatically create prof
	  puts "* Manually create a new entry and give the Prof ID"
	  puts "What do you want to do?"
	  get_user_input(/^[1-9][0-9]*|skip$/, true)
	end
	case action
	  when "skip": next
	  when "add":
	    p = Prof.new(:firstname => p.first,
			  :surname => p.last,
			  :email => p.mail,
			  :gender => [:female, :male].index(gender))
	    p.save
	    next p
	  else
	    p = Prof.find(pid)
	    redo if p.nil?
	    next p
	end
      end
    end


    IMPORT_PATH = "#{GNT_ROOT}/tmp/import/"

    puts
    puts "Before running this task, please ensure the following:"
    puts "* internet connection works"
    puts "* all about-to-be-queried services are online"
    puts "* you placed all manually requested info files into #{simplify_path(IMPORT_PATH)}"
    puts "* ensure all XLS files have been converted to CSV"
    puts "* you know which lectures you want to import"
    puts "* you have a lot of time"
    exit 0 unless get_user_yesno("Continue?")

    require "#{GNT_ROOT}/tools/lsf_parser_base.rb"
    LSF.set_debug = false

    FRIENDS_PATH=IMPORT_PATH
    require "#{GNT_ROOT}/lib/friends.rb"
    friends = nil
    work_queue.enqueue_b { friends = Friends.new }

    puts "Gathering data:"
    # get information about tutors, student count, … ###################
    data = []
    work_queue.enqueue_b { data[0] = MuesliYAML.data }
    work_queue.enqueue_b { data[1] = LaierCSV.data }
    work_queue.enqueue_b { data[2] = UebungenDotPhysik.data }

    # get information about what’s in seee #############################
    # courses will be added to the last semester currently active.
    # Therefore sem references that term, but course titles will include
    # the data of all currently active semesters.
    cst = []
    sem = nil
    forms = {}
    form_names = []
    faculties = []
    work_queue.enqueue_b do
      cs = Semester.currently_active.map { |s| s.courses }.flatten
      cst = cs.map { |c| c.title }
      sem = Semester.currently_active.last
      form_names = sem.forms.map { |f| f.name }
      faculties = Faculty.all
      forms[:seminar] = sem.forms.detect { |f| f.name.match(/seminar/i) }
      forms[:lecture] = sem.forms.detect { |f| f.name.match(/vorlesung|lecture/i) }
    end
    work_queue.join

    # load LSF data ####################################################
    search = ["Mathematik und Informatik", "Fakultät für Physik und Astronomie"]
    maths, physics = LSF.find_certain_roots(search)

    # Convert the URLs to actual data
    physics = []
    work_queue.enqueue_b do
      puts "Loading physics LSF tree…"
      term, rootid = LSF.set_term_and_root(physics[:url])
      physics = LSF.get_tree(rootid)
    end
    work_queue.enqueue_b do
      puts "Loading maths LSF tree…"
      term, rootid = LSF.set_term_and_root(maths[:url])
      maths = LSF.get_tree(rootid)
    end

    # wait for data ####################################################
    work_queue.join
    data.flatten!

    puts "Semester = #{sem.title}"

    # Now process every lecture in the LSF data and merge it with
    # additional data from other sources.
    processed = []
    (maths + physics).each do |lect|
      # skip already imported lectures or ones that have already been
      # processed, but appear more than once in the LSF data
      next if cst.include?(lect.name) || processed.include?(lect.name)
      processed << lect.name
      next unless get_user_yesno("Import #{lect.name}?", :none)
      dat = friends.find_similar(lect.name, data)
      # prefer LSF name because other features in seee rely on that name
      title = lect.name

      # collect lists and merge similar entries. Then try to find them
      # in Seee.
      lects = lect.profs.flatten.uniq.map { |p| "#{p.first} #{p.last}" }
      lects += dat.map { |d| d[:lecturer] }.flatten.compact
      lects = friends.uniq_sim(lects)
      lects = names_to_profs(lects, lect)

      # collect lists and merge similar
      tutors = dat.map { |d| d[:tutors] }.flatten.compact
      tutors = friends.uniq_sim(tutors).sort

      # select smallest number. Try to guess based on tutor count, if
      # there are any tutors but no other data
      students = [999, *dat.map { |d| d[:students] }].compact.min
      students = 999 if students == 0
      students_source = students == 999 ? "not known" : "from data"
      if students == 999 && tutors.size >= 1
	students = 30*tutors.size
	students_source = "guessed from tutor count"
      end

      # automatically select the form if there is reason to believe they
      # match. Otherwise ask the user.
      form_source = "guessed from #{lect.type}"
      form = nil
      form = forms[:seminar] if lect.type.match(/seminar/i)
      form = forms[:lecture] if lect.type.match(/vorlesung|lecture/i)
      if form.nil?
	puts "Couldn’t auto-detect form type for given type: #{lect.type}"
	puts "Please choose which form to use. Valid ones:"
	puts form_names.join("\n")
	input = get_user_input(form_names, true)
	form = sem.forms.detect { |f| f.name == input }
	form_source = "chosen"
      end

      # Guess language. Default to English.
      lang = form.languages.detect(:en) { |l| l.to_s == lect.lang[0..1] }

      # Guess faculty. If there’s no match simply choose any because it
      # can easily be changed any time. Therefore the risk of being
      # wrong is negligible.
      lsf_fac = lect.facul_name.downcase
      avail_fac = faculties.map { |f| f.longname }
      fac = friends.find_most_similar(lsf_fac, avail_fac)
      fac = faculties.detect { |f| f.longname == fac }

      # get user confirmation ##########################################
      puts
      puts "About to import lecture with the following data:"
      puts "Title:     #{title}"
      puts "Lecturers: #{lects.map { |l| "#{l.fullname} (#{l.id})" }.join(", ")}"
      puts "Students:  #{students} (#{students_source})"
      puts "Form:      #{form.name} (#{form_source})"
      puts "Language:  #{lang}"
      puts "Tutors:    #{tutors.join(", ")}"
      puts "Faculty:   #{fac.longname} (guessed)"
      puts
      next unless get_user_yesno("Add the lecture with this data?")

      # well, add it to seee ###########################################
      begin
	cc = Course.new(:semester_id => sem.id,
			:title       => title ,
			:students    => students,
			:form_id     => form.id,
			:language    => lang,
			:faculty_id  => fac.id,
			:evaluator => "", :description => "",
			:summary => "", :fscontact => "", :note => "")
	cc.save
	lects.each { |l| cc.profs << l }
	tutors.each { |t| cc.tutors.build({:abbr_name => t}).save }
	puts "Everything should have worked…"
	puts
	puts
      rescue Exception => e
	warn "An error occured while adding #{title}. Here’s the error:"
	warn e.message
	warn e.backtrace.inspect
	puts "Please try to fix the error before continuing."
	exit 1 unless get_user_yesno("Continue?")
      end
    end

    # if you adjust stuff here, also update Rakefile  misc:lsfparse
    puts "Generating final sheets in tmp/lsfparse…"
    def run(name, data)
      render_tex(LSF.print_final_tex(data), "tmp/lsfparse/lsf_parser_#{name}_final.pdf", true, true)
    end

    work_queue.enqueue_b { run("mathe", maths) }
    work_queue.enqueue_b { run("physik", physics) }
    work_queue.join

    puts "All done!"
  end
end
