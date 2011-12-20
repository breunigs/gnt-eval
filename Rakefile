# -*- coding: utf-8 -*-

require 'rubygems'
require 'action_mailer'
require 'web/config/boot'
require 'web/lib/ext_requirements.rb'
require 'web/lib/FunkyDBBits.rb'
require 'web/lib/RandomUtils.rb'

require 'pp'
require 'yaml'

# needed for image manipulations
require 'RMagick'
require 'ftools'

include Magick

require 'rake/clean'
CLEAN.include('tmp/*.log', 'tmp/*.out', 'tmp/*.aux', 'tmp/*.toc', 'tmp/*/*.log', 'tmp/*/*.out', 'tmp/*/*.aux', 'tmp/*/*.toc', 'tmp/blame.tex')


# load external rakefiles
require 'rakefiles/export.rb'
require 'rakefiles/omr-test-helper.rb'
require 'custom_build/build.rb'

# requires database
def curSem
  $curSem ||= Semester.find(:all).find { |s| s.now? }
  $curSem
end

def find_barcode(filename)
  zbar = Seee::Config.application_paths[:zbar]
  unless File.exist?(zbar)
    puts "Couldn’t find a suitable zbarimg executable. This is likely due to your platform (= #{`uname -m`.strip}) not being supported by default. You can resolve this by running “rake magick:buildZBar”."
    exit 1
  end
  zbar = Seee::Config.commands[:zbar]

  r = `#{zbar} "#{filename}"`
  if not r.empty?
    return r.strip.match(/^([0-9]+)/)[1].to_i
  else
    return nil
  end
end

# Creates a sample sheet in tmp/sample_sheets for the given form (object)
# and language name. Returns the full filepath, but without the file
# extension. Does not re-create existing files.
def make_sample_sheet(form, lang)
  # this is hardcoded throughout the project
  dir = "tmp/sample_sheets/"
  File.makedirs(dir)
  filename = dir + "sample_" + form.id.to_s + (lang == "" ? "" : "_#{lang}")
  #hasTutors = form.questions.map {|q| q.db_column}.include?('tutnum')

  form_misses_files = !File.exist?(filename+'.pdf') || !File.exist?(filename+'.yaml')
  # see if the form is newer than any of the files
  form_needs_regen = form_misses_files \
                      || form.updated_at > File.mtime(filename+'.pdf') \
                      || form.updated_at > File.mtime(filename+'.yaml')


  # PDFs are required for result generation and the posouts for OMR
  # parsing. Only skip if both files are present and newer than the
  # form itself.
  if !form_needs_regen && File.exists?(filename+'.pdf') && File.exists?(filename+'.yaml')
    puts "#{filename}.pdf already exists. Skipping."
    return filename
  end

  generate_barcode("0"*8, dir + "barcode00000000.pdf")

  File.open(filename + ".tex", "w") do |h|
    h << form.abstract_form.to_tex(lang)
  end

  puts "Wrote #{filename}.tex"
  Rake::Task[(filename + '.pdf').to_sym].invoke
  `./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
  filename
end

# Creates form PDF file for given semester and CourseProf
def make_pdf_for(s, cp, dirname)
  # first: the barcode
  generate_barcode(cp.barcode, dirname + "barcode#{cp.barcode}.pdf")

  # second: the form
  filename = dirname + cp.get_filename.gsub(/\s+/,' ').gsub(/^\s|\s$/, "")

  File.open(filename + '.tex', 'w') do |h|
    h << cp.course.form.abstract_form.to_tex(
      cp.course.language,
      cp.course.title,
      cp.prof.firstname,
      cp.prof.lastname,
      cp.prof.gender,
      cp.course.tutors.sort{ |a,b| a.id <=> b.id }.map{ |t| t.abbr_name },
      s.title,
      cp.barcode)
  end
  puts "Wrote #{filename}.tex"

  # generate PDF
  Rake::Task[(filename + '.pdf').to_sym].invoke

  # it may be useful for debugging to have a YAML for each course.
  # however, it is not needed by gnt-eval itself, so remove it immediately
  # before it causes any confusion.
  `rm "#{filename}.posout"`
  #`./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
end

# automatically calls rake -T when no task is given
task :default do
  puts "Choose your destiny:"
  system("rake -sT")
end

namespace :db do
  task :connect do
    $dbh = FunkyDBBits.dbh
  end
end

namespace :images do
  desc "(0) Run the scan script to import pages to #{simplify_path(Seee::Config.file_paths[:scanned_pages_dir])}"
  task :scan do
    File.makedirs(Seee::Config.file_paths[:scanned_pages_dir])
    Dir.chdir(Seee::Config.file_paths[:scanned_pages_dir]) do
      system(Seee::Config.commands[:scan])
    end
  end

  desc "(4) make handwritten comments known to the web-UI (i.e. find JPGs in #{simplify_path(Seee::Config.file_paths[:sorted_pages_dir])})"
  task :insertcomments, :needs => ['db:connect'] do |t, d|
    cp = Seee::Config.commands[:cp_comment_image_directory]
    mkdir = Seee::Config.commands[:mkdir_comment_image_directory]

    expire_course_cache = []
    expire_tutor_cache = []

    system("#{mkdir} -p \"#{Seee::Config.file_paths[:comment_images_public_dir]}/#{curSem.dirFriendlyName}\"")
    path=File.join(File.dirname(__FILE__), "tmp/images")

    # find all existing images for courses/profs and tutors
    cpics = CPic.find(:all)
    tpics = Pic.find(:all)

    # find all tables, that have a tutnum column
    forms = curSem.forms.reject { |form| form.get_question("tutnum").nil? }
    tables = forms.collect { |form| form.db_table }

    allfiles = Dir.glob(File.join(Seee::Config.file_paths[:sorted_pages_dir], '**/*.jpg'))
    allfiles.each_with_index do |f, curr|
      bname = File.basename(f)
      barcode = find_barcode_from_path(f)

      if barcode == 0
        $stderr.print "Couldn’t detect barcode for #{bname}, skipping.\n"
        next
      end

      course_prof = CourseProf.find(barcode)
      if course_prof.nil?
        $stderr.print "Couldn’t find Course/Prof for barcode #{barcode} (image: #{bname}). Skipping.\n"
        next
      end

      p = nil
      # tutor comments, place them under each tutor
      if f.downcase.end_with?("ucomment.jpg")
        # skip existing images
        next if tpics.any? { |x| x.basename == bname }
        # find tutor id
        tut_num = nil
        tables.each do |t|
          # remove everything after the last underscore and add .tif to
          # find the original image
          path = f.sub(/_[^_]+$/, "") + ".tif"
          data = $dbh.execute("SELECT tutnum FROM #{t} WHERE path = ?", path)
          data = data.fetch_array
          tut_num = data[0].to_i if data
          break if tut_num
        end

        if tut_num.nil?
          $stderr.print "Couldn’t find any record in the results database for #{bname}. Cannot match tutor image. Skipping.\n"
          next
        end

        if tut_num == 0
          $stderr.print "Couldn’t add tutor image #{bname}, because no tutor was chosen (or marked invalid). Skipping.\n"
          next
        end

        # load tutors
        tutors = course_prof.course.tutors.sort { |a,b| a.id <=> b.id }

        if tut_num > tutors.count
          $stderr.print "Couldn’t add tutor image #{bname}, because chosen tutor does not exist (checked field num > tutors.count). Skipping.\n"
          next
        end

        p = Pic.new
        p.tutor_id = tutors[tut_num-1].id
        expire_tutor_cache << tutors[tut_num-1]
      else # files for the course/prof. Should be split up. FIXME.
        next if cpics.any? { |x| x.basename == bname }
        p = CPic.new
        p.course_prof = course_prof
        expire_course_cache << course_prof.course
      end
      p.basename = bname
      # let rails know about this comment
      p.save
      # move comment to correct location
      system("#{cp} \"#{f}\" \"#{Seee::Config.file_paths[:comment_images_public_dir]}/#{curSem.dirFriendlyName}/\"")
      print_progress(curr+1, allfiles.size)
    end # Dir glob

    puts "Expiring caches for courses#edit and tutors#edit"
    expire_course_cache.each { |c| expire_page :controller => "courses", :action => "edit", :id => c }
    expire_tutor_cache.each { |t| expire_page :controller => "tutors", :action => "edit", :id => t }

    puts
    puts "Done."
  end

  desc "(1) Sort scanned images by barcode (#{simplify_path(Seee::Config.file_paths[:scanned_pages_dir])} → #{simplify_path(Seee::Config.file_paths[:sorted_pages_dir])})"
  task :sortandalign, :directory do |t, d|
    # use default directory if none given
    if d.directory.nil? || d.directory.empty?
      d = {}
      puts "No directory given, using default one: #{simplify_path(Seee::Config.file_paths[:scanned_pages_dir])}"
      d[:directory] = Seee::Config.file_paths[:scanned_pages_dir]
      File.makedirs(d[:directory])
      puts d
    end

    # abort if the directory of choice does not exist for some reason
    if !File.directory?(d[:directory])
      puts "Given directory does not exist. Aborting."
    # actually sort the images
    else
      puts "Working directory is: #{d[:directory]}"
      files = Dir.glob(File.join(d[:directory], '*.tif'))
      sort_path = Seee::Config.file_paths[:sorted_pages_dir]

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

          if zbar_result.nil? || (not CourseProf.exists?(barcode))
            puts "\nbizarre #{basename}: " + (zbar_result.nil? ? "Barcode not found" : "CourseProf (#{zbar_result}) does not exist")
            File.makedirs(File.join(sort_path, "bizarre"))
            File.move(f, File.join(sort_path, "bizarre"))
          else
            form = CourseProf.find(barcode).course.form.id.to_s + '_' +
              CourseProf.find(barcode).course.language.to_s

            File.makedirs(File.join(sort_path, form))
            File.move(f, File.join(sort_path, form, "#{barcode}_#{basename}.tif"))
          end

          curr += 1
          print_progress(curr, files.size)
        end
      end
      work_queue.join
    end # else
  end
end

namespace :mail do
  desc "send reminder mails to FSlers"
  task :reminder do
    s = Semester.find(:all).find{ |s| s.now? }

    puts ("This will send reminder mails to _all_ fscontacts for courses " +
      "in semester #{s.title}. I will now show you a list of the mails, " +
      "that I will send. After you have seen the list, you will still be " +
      "able to abort.\nPlease press Enter.").word_wrap
    $stdin.gets

    s.courses.each do |c|
      puts "For '#{c.title} I would send mail to #{c.fs_contact_addresses}"
    end

    puts "\n\nIf you really (and I mean REALLY) want to do this, type in 'Jasper ist doof':"
    check = $stdin.gets.chomp
    if check == 'Jasper ist doof'
      Postoffice.view_paths = ['web/app/views/']
      s.courses.each do |c|
        Postoffice.deliver_erinnerungsmail(c.id)
        puts "Delivered mail for #{c.title} to #{c.fs_contact_addresses}."
      end
    else
      puts "K, won't do anything."
    end
  end
end

namespace :pest do
  # find forms for current semester and extract variables from the
  # first key that comes along. The language should exist for every
  # key, even though this is currently not enforced. Will be though,
  # once a graphical form creation interface exists.
  desc "Finds all different forms for each folder and saves the form file as #{simplify_path(Seee::Config.file_paths[:sorted_pages_dir])}/[form id].yaml."
  task :getyamls do |t,o|
    `mkdir -p ./tmp/images`
    curSem.forms.each do |form|
      form.abstract_form.lecturer_header.keys.collect do |lang|
        target = File.join(Seee::Config.file_paths[:sorted_pages_dir], "#{form.id}_#{lang}.yaml")
        next if File.exists?(target)
        file = make_sample_sheet(form, lang)
        `./pest/latexfix.rb "#{file}.posout"`
        `mv -f "#{file}.yaml" "#{target}"`
      end
    end
  end

  desc "(2) Evaluates all sheets in #{simplify_path(Seee::Config.file_paths[:sorted_pages_dir])}"
  task :omr, :needs => 'pest:getyamls' do
    # OMR needs the YAML files as TeX also outputs position information
    p = Seee::Config.file_paths[:sorted_pages_dir]
    Dir.glob(File.join(p, "[0-9]*.yaml")).each do |f|
      puts "Now processing #{f}"
      bn = File.basename(f, ".yaml")
      system("./pest/omr2.rb -s \"#{f}\" -p \"#{p}/#{bn}\" -c #{number_of_processors}")
    end
  end

  desc "(3) Correct invalid sheets"
  task :correct do
    require File.join(Rails.root, "lib", "AbstractForm.rb")
    tables = curSem.forms.collect { |form| form.db_table }
    `./pest/fix.rb #{tables.join(" ")}`
  end
end

namespace :pdf do
  desc "create samples for all available sheets for printing or inclusion. leave semester_id empty for current term."
  task :samplesheets, :semester_id do |t,a|
    sem = a.semester_id.nil? ? curSem : Semester.find(a.semester_id)
    sem.forms.each do |f|
      f.languages.each do |l|
        work_queue.enqueue_b { make_sample_sheet(f, l) }
      end
    end
    work_queue.join
    Rake::Task["clean".to_sym].invoke
  end

  desc "makes the result pdfs preliminary"
  task :make_preliminary do
    p = "./tmp/results"
    Dir.glob("#{p}/*.pdf") do |d|
      d = File.basename(d)
      next if d.match(/^preliminary_/)
      work_queue.enqueue_b do
        puts "Working on " + d
        `pdftk #{p}/#{d} background ./helfer/wasserzeichen.pdf output #{p}/preliminary_#{d}`
      end
    end
    work_queue.join
    Rake::Task["clean".to_sym].invoke
  end

  # This is a helper function that will create the result PDF file for a
  # given semester and faculty_id in the specified directory.
  def evaluate(semester_id, faculty_id, directory)
      f = Faculty.find(faculty_id)
      s = Semester.find(semester_id)

      puts "Could not find specified faculty (id = #{faculty_id})" if f.nil?
      puts "Could not find specified semester (id = #{semester_id})" if s.nil?
      return if f.nil? || s.nil?

      filename = f.longname.gsub(/\s+/,'_').gsub(/^\s|\s$/, "")
      filename << '_' << s.dirFriendlyName
      filename << '_' << (I18n.tainted? ? "mixed" : I18n.default_locale).to_s
      filename << '.tex'

      File.open(directory + filename, 'w') do |h|
        h.puts(s.evaluate(f))
      end

      puts "Wrote #{directory+filename}"
      Rake::Task[(directory+filename.gsub(/tex$/, 'pdf')).to_sym].invoke
  end

  desc "create report pdf file for a given semester and faculty (leave empty for: lang = mixed, sem = current, fac = all)"
  task :semester, :lang_code, :semester_id, :faculty_id do |t, a|
    sem = a.semester_id.nil? ? curSem.id : a.semester_id
    lang_code = a.lang_code || "mixed"

    dirname = './tmp/results/'
    FileUtils.mkdir_p(dirname)

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

      Rake::Task["pdf:samplesheets".to_sym].invoke
      evaluate(sem, a.faculty_id, dirname)
      exit
    end

    # no faculty specified, just find all and process them in parallel.
    Faculty.find(:all).each do |f|
      args = [lang_code, sem, f.id].join(",")
      job = fork { exec "rake pdf:semester[#{args}]" }
      # we don't want to wait for the process to finish
      Process.detach(job)
    end
  end

  desc "create pdf-form-files corresponding to each course and prof (leave empty for current semester)"
  task :forms, :semester_id, :needs => 'db:connect' do |t, a|
    dirname = './tmp/forms/'
    FileUtils.mkdir_p(dirname)

    sem = a.semester_id.nil? ? curSem.id : a.semester_id
    s = Semester.find(sem)

    CourseProf.find(:all).find_all { |x| x.course.semester == s }.each do |cp|
      work_queue.enqueue_b { make_pdf_for(s, cp, dirname) }
    end
    work_queue.join

    Rake::Task["clean".to_sym].invoke
  end

  desc "Create How Tos"
  task :howto, :needs => 'db:connect' do
    saveto = './tmp/howtos/'
    FileUtils.mkdir_p(saveto)
    form_path = File.expand_path(File.join(RAILS_ROOT, "../tmp/forms")).escape_for_tex

    dirname = Seee::Config.file_paths[:forms_howto_dir]
    # Escape for TeX
    dirname << Semester.find(:last).dirFriendlyName.gsub('_', '\_')
    threads = []
    Dir.glob("./doc/howto_*.tex").each do |f|
      work_queue.enqueue_b do

        data = File.read(f).gsub(/§§§/, form_path)
        file = saveto + File.basename(f)
        File.open(file, "w") { |x| x.write data }
        Rake::Task[(file.gsub(/\.tex$/, ".pdf")).to_sym].invoke
        File.delete(file)
      end
    end
    work_queue.join
    Rake::Task["clean".to_sym].invoke
  end

  desc "Create tutor blacklist for current semester"
  task :blacklist do
    include FunkyTeXBits
    class Float
      def rtt
        return ((self*10).round.to_f)/10
      end
    end
    class NilClass
      def rtt
        return nil
      end
    end
    f = File.open('./tmp/tutors.tex', 'w') do |f|
      f.puts blacklist_head(curSem.title)
      tutors = curSem.courses.collect { |c| c.tutors }.flatten.sort { |x,y| x.abbr_name <=> y.abbr_name }
      tutors.each do |t|
        f.puts [t.abbr_name, t.course.title[0,20], t.profit.rtt, t.teacher.rtt, t.competence.rtt, t.preparation.rtt, t.sheet_count].join(' & ') + '\\\\'
      end
      f.puts blacklist_foot
    end
    Rake::Task['./tmp/tutors.pdf'.to_sym].invoke
    File.delete './tmp/tutors.tex'
  end
end


namespace :helper do
  desc "Creates required amount of copies /within/ a PDF file. This saves you from having to specify the amount of copies when printing each form manually."
  task :multiply_pdfs do
    system("./helfer/multiply_pdfs.rb tmp")
  end

  desc "Generate printable event lists 'what to eval?' and 'who evals what?'. Also creates import YAML for Kummerkasten."
  task :lsfparse do
    puts "Finding IDs…"
    require 'net/http'
    url = "http://lsf.uni-heidelberg.de/qisserver/rds?state=wtree&search=1&category=veranstaltung.browse&topitem=lectures&subitem=lectureindex&breadcrumb=lectureindex"

    req = Net::HTTP.get_response(URI.parse(url))
    mathe = req.body.scan(/href="([^"]+?)"\s+?title="'Fakultät für Mathematik und Informatik/)[0][0]
    physik = req.body.scan(/href="([^"]+?)"\s+?title="'Fakultät für Physik und Astronomie/)[0][0]

    dir = "tmp/lsfparse/"
    File.makedirs(dir)

    puts "Mathe…"
    `cd '#{dir}' && ../../helfer/lsf_parser_api.rb mathe '#{mathe}' > mathe.log`
    puts "Physik…"
    `cd '#{dir}' && ../../helfer/lsf_parser_api.rb physik '#{physik}' > physik.log`

    puts
    puts "All Done. Have a look in #{dir}"
  end

  desc "Grabs the current list of tutors from uebungen.physik.uni-hd.de and puts them into a human readable file"
  task :tutors_physics do
    `cd tmp && ./../tools/physik_tutoren.rb`
    require 'date'
    puts Date.today.strftime("Done, have a look at: tmp/%Y-%m-%d Tutoren Physik.txt")
  end

  desc "Tries to find suitable files in ./tmp that might contain tutor/lecutre information for the maths fac."
  task :tutors_maths do
    Dir.chdir("tmp")
    # selecting all "yml"s is okay because by default only "yamls" are
    # written into /tmp by other parts
    ymls = Dir.glob("*.yml") + Dir.glob("mues*.yaml") + Dir.glob("lect*.yaml")
    csv = Dir.glob("Hiwi*.csv")
    xls = Dir.glob("Hiwi*.xls")
    files = '"'+(ymls + csv + xls).join('" "')+'"'
    puts "Files found: #{files}"
    system("./../helfer/mathe_tutoren.rb #{files}")
  end

  desc "Generate lovely HTML output for our static website"
  task :static_output do
    puts curSem.courses.sort { |x,y| y.updated_at <=> x.updated_at }[0].updated_at
    # Sort by faculty first, then by course title
    sorted = curSem.courses.sort do |x,y|
      if x.faculty_id == y.faculty_id
        x.title <=> y.title
      else
        x.faculty_id <=> y.faculty_id
      end
    end
    facs = Faculty.find(:all)
    fac_id = -1

    def printTD(stuff, join = ", ", extra = "")
      s = "<td>" if extra.empty?
      s = "<td style=\"#{extra}\">" unless extra.empty?
      if stuff.is_a? Array
        s << stuff.join(join) unless stuff.empty?
      elsif stuff.is_a? String
        s << stuff
      end
      s << "</td>"
      s
    end

    odd = true
    sorted.each do |c|
      # faculty changed, so print header
      if fac_id != c.faculty_id
        fname = facs.find { |f| f.id == c.faculty_id }.longname
        puts "</table>" unless fac_id == -1
        puts "<h2>#{fname}</h2>"
        puts "<table class=\"aligntop\" summary=\"Veranstaltungen der Fakultät für #{fname}\">"
        puts "<tr class=\"odd\">"
        puts "<th></th>"
        puts "<th>Veranstaltung</th>"
        puts "<th>DozentInnen</th>"
        puts "<th>Wann?</th>"
        puts "<th>Tutoren</th></tr>"
      end
      puts "<tr>" if odd
      puts "<tr class=\"odd\">" if !odd
      tuts = c.tutors.collect{ |t| t.abbr_name }
      profs = c.profs.collect{ |t| t.fullname }
      hasEval = c.fs_contact_addresses.empty? ? "&nbsp;" : "&#x2713;"

      puts printTD(hasEval)
      puts printTD(c.title.gsub("&", "&amp;"))
      puts printTD(profs, "<br/>", "white-space: nowrap")
      puts printTD(c.description)
      puts printTD(tuts)
      puts "</tr>"
      fac_id = c.faculty_id
      odd = !odd
    end
    puts "</table>"
  end

  desc "Generate crappy output sorted by day for simplified packing"
  task :packing_sheet do
    crap = '<meta http-equiv="content-type" content=
  "text/html; charset=utf-8"><style> td { border-right: 1px solid #000; } .odd { background: #eee; }</style><table>'
    # used for sorting
    h = Hash["mo", 1, "di", 2, "mi", 3, "do", 4, "fr", 5, "??", 6]
    # used for counting
    count = Hash["mo", 0, "di", 0, "mi", 0, "do", 0, "fr", 0, "??", 0]
    d = curSem.courses.sort do |x,y|
      a = x.description.strip.downcase
      b = y.description.strip.downcase

      a = "??" if a.length < 2 || !h.include?(a[0..1])
      b = "??" if b.length < 2 || !h.include?(b[0..1])

      if h[a[0..1]] > h[b[0..1]]
        1
      elsif h[a[0..1]] < h[b[0..1]]
        -1
      else
        b <=> a
      end
    end

    odd = false
    d.each do |c|
       odd = !odd
       day = c.description.strip[0..1].downcase
       day = "??" if day.length < 2 || !count.include?(day[0..1])
       count[day] += 1
       if odd
         crap << "<tr>"
       else
         crap << "<tr class='odd'>"
       end
       crap << "<td>#{c.description}</td>"
       crap << "<td>#{c.title}</td>"
       crap << "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>"
       crap << "<tr>"
    end
    crap << "</table><br><br>"
    count.each { |k,v| crap << "#{k}: #{v}<br/>" }
    `mkdir -p ./tmp/`
    p = './tmp/mappen_packen.html'
    File.open(p, 'w') {|f| f.write(crap) }
    `x-www-browser #{p}`
    puts "Wrote and opened #{p}"
  end
end

namespace :summary do
  def fixCommonTeXErrors(code)
    # _ -> \_, '" -> "', `" -> "`
    code = code.gsub(/([^\\])_/, '\1\\_').gsub(/`"/,'"`').gsub(/'"/, '"\'')
    # correct common typos
    code = code.gsub("\\textit", "\\emph")
    code = code.gsub("{itemsize}", "{itemize}").gsub("/begin{", "\\begin{")
    code = code.gsub("/end{", "\\end{").gsub("/item ", "\\item ")
    code = code.gsub("\\beign", "\\begin").gsub(/[.]{3,}/, "\\dots ")
    code
  end

  def warnAboutCommonTeXErrors(code)
    msg = []

    msg << "Plain (i.e. \") quotation mark use?" if code.match("\"")
    msg << "Unexpanded “&”?" if code.match("\\&")
    msg << "Deprecated quotation mark use?" if code.match("\"`")
    msg << "Deprecated quotation mark use?" if code.match("\"'")
    msg << "Underline mustn't be used. Ever." if code.match("\\underline")
    msg << "Unescaped %-signs?" if code.match(/[^\\]%/)

    begs = code.scan(/\\begin\{[a-z]+?\}/)
    ends = code.scan(/\\end\{[a-z]+?\}/)
    if  begs.count != ends.count
        msg << "\\begin and \\end count differs. This is what has been found:"
        msg << "\tBegins: #{begs.join("\t")}"
        msg << "\tEnds:   #{ends.join("\t")}"
    end

    msg.collect { |x| "\t" + x }.join("\n")
  end

  desc "fix some often encountered tex-errors in the summaries"
  task :fixtex do
    curSem.courses.each do |c|
      unless c.summary.nil?
        c.summary = fixCommonTeXErrors(c.summary)
        c.save

        warn = warnAboutCommonTeXErrors(c.summary)
        unless warn.empty?
            puts "Warnings for: #{c.title}"
            puts warn + "\n\n"
        end
      end

      c.tutors.each do |t|
        next if t.comment.nil?

        t.comment = fixCommonTeXErrors(t.comment)
        t.save

        warn = warnAboutCommonTeXErrors(t.comment)
        unless warn.empty?
            puts "Warnings for: #{c.title} / #{t.abbr_name}"
            puts warn + "\n\n"
        end
      end
    end
  end

  # Puts the given content into a blame file and adds basic
  # header and footer. Immediately TeXes the file and reports
  # error code
  def testTeXCode(content)
    include FunkyTeXBits

    I18n.load_path += Dir.glob(File.join(Rails.root, '/config/locales/*.yml'))

    head = preamble("Blaming Someone For Bad LaTeX")
    foot = "\\end{document}"

    File.open("./tmp/blame.tex", 'w') do |f|
        f.write(head)
        f.write(content)
        f.write(foot)
    end

    `cd ./tmp/ && #{Seee::Config.commands[:pdflatex_fast]} blame.tex 2>&1`
    $?
  end

  desc "find comment fields with broken LaTeX code"
  task :blame do
    curSem.courses.each_with_index do |c, i|
      unless c.summary.nil? || c.summary.empty?
        if testTeXCode(c.summary) != 0
            puts "\rTeXing course comments failed: #{c.title}"
        end
      end

      c.tutors.each do |t|
        next if t.comment.nil? || t.comment.empty?
        if testTeXCode(t.comment) != 0
            puts "\rTeXing tutor  comments failed: #{c.title} / #{t.abbr_name} "
        end
      end
      print_progress(i + 1, curSem.courses.size)
    end
    puts "\nIf there were errors you might want to try"
    puts "\trake summary:fixtex"
    puts "first before fixing manually."
  end
end

rule '.pdf' => '.tex' do |t|
    filename="\"#{File.basename(t.source)}\""
    texpath="cd \"#{File.dirname(t.source)}\";"

    # run it once fast, to see if there are any syntax errors in the
    # text and create first-run-toc
    err = `#{texpath} #{Seee::Config.commands[:pdflatex_fast]} #{filename} 2>&1`
    if $?.exitstatus != 0
        puts "="*60
        puts err
        puts "\n\n\nERROR WRITING: #{t.name}"
        puts "EXIT CODE: #{$?}"
        puts "="*60
        puts "Running 'rake summary:fixtex' or 'rake summary:blame' might help."
        exit
    end

    # run it fast a second time, to get /all/ references correct
   `#{texpath} #{Seee::Config.commands[:pdflatex_fast]} #{filename} 2>&1`
    # now all references should have been resolved. Run it a last time,
    # but this time also output a pdf
    `#{texpath} #{Seee::Config.commands[:pdflatex_real]} #{filename} 2>&1`

    if $?.exitstatus == 0
        puts "Wrote #{t.name}"
    else
        puts "Some other error occured. It shouldn't be TeX-related, as"
        puts "it already passed one run. Well, happy debugging."
    end
end
