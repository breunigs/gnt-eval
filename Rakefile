# -*- coding: utf-8 -*-

require 'rubygems'
require 'action_mailer'
require 'web/config/boot'
require 'web/lib/ext_requirements.rb'
require 'web/lib/FunkyDBBits.rb'
require 'web/lib/RandomUtils.rb'
require 'custom_build/build.rb'
require 'pp'


# need for parsing yaml into database
require 'yaml'

# needed for image manipulations
require 'RMagick'
require 'ftools'

include Magick

require 'rake/clean'
CLEAN.include('tmp/*.log', 'tmp/*.out', 'tmp/*.aux', 'tmp/*.toc', 'tmp/*/*.log', 'tmp/*/*.out', 'tmp/*/*.aux', 'tmp/*/*.toc', 'tmp/blame.tex')

# requires database
def curSem
  $curSem ||= Semester.find(:all).find { |s| s.now? }
  $curSem
end

def find_barcode(filename)
  r = `#{Seee::Config.commands[:zbar]} #{filename}`
  if not r.empty?
    return r.strip.match(/^([0-9]+)/)[1].to_i
  else
    return nil
  end
end

def find_barcode_from_basename(basename)
    basename.to_s.sub(/^.*_/, '').to_i
end

def tex_head_for(form, lang='')
  h = form.abstract_form.texhead
  if h.is_a?(String)
    h
  else
    h[lang]
  end
end

def tex_foot_for(form, lang='')
  f = form.abstract_form.texfoot
  if f.is_a?(String)
    f
  else
    f[lang]
  end
end

def tex_questions_for(form, lang)
  b = ""
  form.pages.each_with_index do |p,i|
    b << p.tex_at_top.to_s
    p.sections.each do |s|
      # ist das ein abschnitt, der uns kümmert?
      next if s.questions.find_all{|q| q.special_care != 1}.empty?
      b << "\n\n" + '\sect{' + s.title[lang] + "}"
      s.questions.each do |q|
        b << "\n\n"
        next if (q.special_care == 1 || (not q.donotuse.nil?)) && (not q.db_column =~ /comment/)
        if q.db_column =~ /comment/
          b << '\kommentar{' + q.text(lang) + '}{' + q.db_column + '}{' +
            q.db_column + "}\n\n"
        else
          b << '\q' + ['ii','iii','iv','v', 'vi'][q.size - 2]
          b << 'm' if q.multi?
          b << "{#{q.text(lang)}}"
          b << q.boxes.sort{ |x,y| x.choice <=> y.choice }.map{ |x| '{' +
            x.text[lang].to_s + '}' }.join('')
          if q.multi?
            b << '{' + q.db_column.first[0..-2] + '}'
          else
            b << "{#{q.db_column}}"
          end
        end
      end
    end
    b << p.tex_at_bottom.to_s
    b << "\\np\n\n" unless i == (form.pages.count - 1)
  end
  b
end

def tex_none(language)
  I18n.locale = language
  I18n.load_path += Dir.glob(File.join(Rails.root, 'config/locales/*.yml'))
  I18n.t(:none)
end

def make_sample_sheet(form, lang)
  dir = "tmp/sample_sheets/"
  File.makedirs(dir)
  filename = dir + "sample_" + form.id.to_s + (lang == "" ? "" : "_#{lang}")
  hasTutors = form.questions.map {|q| q.db_column}.include?('tutnum')

  if File.exists? filename+'.pdf'
    puts "#{filename}.pdf already exists. Skipping."
    return
  end

  generate_barcode("00000000", dir + "barcode.pdf")
  File.open(filename + ".tex", "w") do |h|
    h << '\documentclass[ngerman]{eval}' + "\n"
    h << '\dozent{Fachschaft MathPhys}' + "\n"
    h << '\vorlesung{Musterbogen für die Evaluation}' + "\n"
    h << '\dbtable{oliver_ist_doof}' + "\n"
    h << '\semester{'+ (curSem.title) +'}' + "\n"

    if hasTutors
      h << '\tutoren{'
      h << '\mmm[1][Mustafa Mustermann] & \mmm[2][Fred Nurk]     & \mmm[3][Ashok Kumar] & \mmm[4][Juan Pérez]     & \mmm[5][Jakob Mierscheid] \\\\'
      h << '\mmm[6][Iwan Iwanowitsch]   & \mmm[7][Pierre Dupont] & \mmm[8][John Smith]  & \mmm[9][Eddi Exzellenz] & \mmm[10][Joe Bloggs]      \\\\'
      h << '\mmm[11][John Doe]          & \mmm[12][\ ]           & \mmm[13][\ ]         & \mmm[14][\ ]            & \mmm[15][\ ]              \\\\'
      h << '\mmm[16][\ ]                & \mmm[17][\ ]           & \mmm[18][\ ]         & \mmm[19][\ ]            & \mmm[20][\ ]              \\\\'
      h << '\mmm[21][\ ]                & \mmm[22][\ ]           & \mmm[23][\ ]         & \mmm[24][\ ]            & \mmm[25][\ ]              \\\\'
      h << '\mmm[26][\ ]                & \mmm[27][\ ]           & \mmm[28][\ ]         & \mmm[29][\ ]            & \mmm[30][\ keine]            }'
    end

    h << '\begin{document}' + "\n"
    h << tex_head_for(form, lang) + "\n\n\n"
    h << tex_questions_for(form, lang) + "\n"
    h << '\end{document}'
  end

  puts "Wrote #{filename}.tex"
  Rake::Task[(filename + '.pdf').to_sym].invoke
end

def escape_for_tex(string)
  # escapes & and % signs if not already done so
  string.gsub(/\\?&/, '\\\&').gsub(/\\?%/, '\\\%')
end

# Creates form PDF file for given semester and CourseProf
def make_pdf_for(s, cp, dirname)
  # first: the barcode
  generate_barcode(cp.barcode, dirname + "barcode.pdf")

  # second: the form
  filename = dirname + cp.get_filename.gsub(/\s+/,' ').gsub(/^\s|\s$/, "")

  File.open(filename + '.tex', 'w') do |h|
    h << '\documentclass[ngerman]{eval}' + "\n"
    h << '\dbtable{' + escape_for_tex(cp.course.form.db_table) + "}\n"
    h << '\dozent{' + escape_for_tex(cp.prof.fullname) + '}' + "\n"
    h << '\vorlesung{' + escape_for_tex(cp.course.title) + '}' + "\n"
    h << '\semester{' + escape_for_tex(s.title) + '}' + "\n"

    # FIXME: insert check for tutors.empty? and also sort them into a different directory!
    if cp.course.form.questions.map { |q| q.db_column}.include?('tutnum')
      none = tex_none(cp.course.language)
      h << '\tutoren{' + "\n"

      tutoren = cp.course.tutors.sort{ |a,b| a.id <=> b.id }.map{ |t| t.abbr_name } + (["\\ "] * (29-cp.course.tutors.count)) +  ["\\ #{none}"]

      tutoren.each_with_index do |t, i|
        t = escape_for_tex(t)
        h << "\\mmm[#{(i+1)}][#{t}] #{(i+1)%5==0 ? "\\\\ \n" : " & "}"
      end

      h << '}' + "\n"
    end

    lang = cp.course.language.to_sym
    h << '\begin{document}' + "\n"
    h << tex_head_for(cp.course.form, lang) + "\n\n\n"
    h << tex_questions_for(cp.course.form, lang) + "\n"
    h << tex_foot_for(cp.course.form, lang) + "\n"
    h << '\end{document}'
  end
  puts "Wrote #{filename}.tex"
  Rake::Task[(filename + '.pdf').to_sym].invoke

  `./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
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

  desc "(5) Insert comment pictures from YAML/jpg in directory. Leave directory empty for useful defaults."
  task :insertcomments, :directory, :needs => 'pest:copycomments' do |t, d|
    dd = d.directory.nil? ? "./tmp/images/**/" : d.directory
    puts "Working directory is #{dd}."

    # find all existing images for courses/profs and tutors
    cpics = CPic.find(:all)
    tpics = Pic.find(:all)

    allfiles = Dir.glob(File.join(dd, '*.yaml'))
    allfiles.each_with_index do |f, curr|
      basename = File.basename(f, '.yaml')
      curdir = File.dirname(f)

      # find comments for the tutors
      # FIXME hardcoded stuff, should be elsewhere, get this from form
      tname = basename + 'ucomment.jpg'

      if File.exists?(File.join(curdir, tname)) && tpics.select { |x| x.basename == tname }.empty?
        # FIXME: need to think of something nicer.
        class Question
          attr_accessor :value
        end
        scan = YAML::load(File.read(f))
        tutnum = scan.questions.find{ |q| q.db_column == "tutnum" }.value.to_i
        barcode = find_barcode_from_basename(basename)

        course = CourseProf.find(barcode).course

        # first checkbox is 1! (0 means 'no choice')
        if tutnum > 0
          tutors = course.tutors.sort{ |a,b| a.id <=> b.id }
          if tutnum > tutors.count
            $stderr.print "\rDid nothing with #{basename}, #{tutnum} > #{tutors.count}\n"
          else
            p = Pic.new
            p.tutor_id = tutors[tutnum-1].id
            p.basename = basename + 'ucomment.jpg'
            p.save
            #~ puts "Inserted #{p.basename} for #{tutors[tutnum-1].abbr_name} as #{p.id}"
          end
        else
          $stderr.print "\rDid nothing with #{basename}, tutnum is 0 (no choice made)\n"
        end
      end

      # finds comments for uhm… seminar sheet maybe?
      # FIXME: is this ever used? if not: EXTERMINATE!
      xname = basename + '-comment.jpg'
      if File.exists?(File.join(curdir, xname)) && cpics.select { |x| x.basename == xname }.empty?
        barcode = find_barcode_from_basename(basename)

        course_prof = CourseProf.find(barcode)

        p = CPic.new
        p.course_prof = course_prof
        p.basename = basename + '-comment.jpg'
        p.save
        #~ puts "Inserted #{p.basename} for #{course_prof.prof.fullname}: #{course_prof.course.title} as #{p.id}"
      end

      # insert comments for profs
      cname = basename + 'vcomment.jpg'
      if File.exists?(File.join(curdir, cname)) && cpics.select { |x| x.basename == cname }.empty?
        barcode = find_barcode_from_basename(basename)

        course_prof = CourseProf.find(barcode)

        p = CPic.new
        p.course_prof = course_prof
        p.basename = basename + 'vcomment.jpg'
        p.save
        #~ puts "Inserted #{p.basename} for #{course_prof.prof.fullname}: #{course.title} as #{p.id}"
      end

      print_progress(curr+1, allfiles.size)
    end # Dir glob

    puts
    puts "Please ensure that all comment pictures have been supplied to"
    puts "\t#{Seee::Config.file_paths[:comment_images_public_dir]} /#{curSem.dirfriendly_title}"
    puts "as that's where the web-seee will look for it."
    puts "This should have been done for you automatically, but you can"
    puts "run it again if it makes you feel better:"
    puts "\trake pest:copycomments"
  end

  desc "(1) Work on the .tif's in directory and sort'em to tmp/images/..."
  task :sortandalign, :directory do |t, d|
    if d.directory.nil? || d.directory.empty? || !File.directory?(d.directory)
      puts "No directory given or directory does not exist."
    else
      puts "Working directory is: #{d.directory}"
      files = Dir.glob(File.join(d.directory, '*.tif'))
      files_size = files.size
      split = files.chunk(number_of_processors)
      curr = 0
      threads = []
      split.each do |files|
        threads << Thread.new do
          files.each do |f|
            unless File.writable?(f)
              puts "No write access, cancelling."
              break
            end

            basename = File.basename(f, '.tif')
            barcode = (find_barcode(f).to_f / 10).floor.to_i

            if barcode.nil? || (not CourseProf.exists?(barcode))
              puts "bizarre #{basename}, exiting"
              File.makedirs('tmp/images/bizarre')
              File.move(f, 'tmp/images/bizarre')
              next
            end

            form = CourseProf.find(barcode).course.form.id.to_s + '_' +
              CourseProf.find(barcode).course.language.to_s

            File.makedirs("tmp/images/#{form}")
            File.move(f, File.join("tmp/images/#{form}", basename + '_' + barcode.to_s + '.tif'))

            #~ puts "Moved to #{form}/#{basename} (#{barcode})"
            curr += 1
            print_progress(curr, files_size)
          end
        end # thread
      end # split
      threads.each { |t| t.join }
    end # else
  end
end

namespace :mail do
  desc "send reminder mails to FSlers"
  task :reminder do
    s = Semester.find(:all).find{ |s| s.now? }

    puts word_wrap("This will send reminder mails to _all_ fscontacts for courses " +
                   "in semester #{s.title}. I will now show you a list of the mails, " +
                   "that I will send. After you have seen the list, you will still be " +
                   "able to abort.\nPlease press Enter.", 72)
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
  def getYamls(overwrite = false)
    # FIXME: This can surely be done simpler by directly finding
    # a form for the current semester
    Dir.glob("./tmp/images/[0-9]*/").each do |f|
      target = "#{f}../#{File.basename(f)}.yaml"
      next if File.exists?(target) && !overwrite
      Dir.glob("#{f}*.tif") do |y|
        # just take the first sheet, as all sheets in the same folder
        # should be identical
        barcode = find_barcode_from_basename(File.basename(y, ".tif"))
        cp = CourseProf.find(barcode)
        make_pdf_for(cp.course.semester, cp, f)
        `mv -f "#{f + cp.get_filename}.yaml" "#{target}"`
        break
      end
    end
  end

  desc 'Finds all different forms for each folder and saves the form file as tmp/images/[form id].yaml'
  task :getyamls, :needs => 'db:connect' do |t|
    getYamls(true)
  end

  # note: this is called automatically by yaml2db
  desc "Create db tables for each form for the current semester"
  task :createtables, :needs => 'db:connect' do
    curSem.forms.each do |f|
      name = f.name
      f = f.abstract_form

      # Note that the barcode is only unique for each CourseProf, but
      # not for each sheet. That's why path is used as unique key.
      q = "CREATE TABLE IF NOT EXISTS `" + f.db_table + "` ("
      q << "`path` VARCHAR(255) CHARACTER SET utf8 NOT NULL UNIQUE, "
      q << "`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT, "
      q << "`barcode` INT(11) default NULL, "

      f.questions.each do |quest|
        next if quest.db_column.nil?
        if quest.db_column.is_a?(Array)
          quest.db_column.each do |a|
            q << "`#{a}` SMALLINT(6) UNSIGNED, "
          end
        else
          q << "`#{quest.db_column}` SMALLINT(6) UNSIGNED, "
        end
      end

      q << "PRIMARY KEY (id)"
      q << ");"
      puts "Creating #{name} (#{f.db_table})"
      $dbh.do(q)
    end
  end

  desc "(2) Evaluates all sheets in ./tmp/images/"
  task :omr do
    getYamls
    Dir.glob("./tmp/images/[0-9]*.yaml").each do |f|
      puts "Now processing #{f}"
      bn = File.basename(f, ".yaml")
      system("./pest/omr.rb -s \"#{f}\" -p \"./tmp/images/#{bn}\" -c #{number_of_processors}")
    end
  end

  desc "(3) Correct invalid sheets"
  task :correct do
    `./pest/fix.rb ./tmp/images/`
  end

  desc "(4) Copies YAML data into database. Append update only, if you really want to re-insert existing YAMLs into the database."
  task :yaml2db, :update, :needs => ['db:connect', 'pest:createtables'] do |t,a|
    class Question
      attr_accessor :value
    end

    update = !a.update.nil? && a.update == "update"
    puts "Will be updating already existing entries." if update

    tables = {}
    Dir.glob("./tmp/images/[0-9]*.yaml") do |f|
      form = File.basename(f, ".yaml")
      yaml = YAML::load(File.read(f))
      tables[form] = yaml.db_table
    end


    allfiles = Dir.glob("./tmp/images/[0-9]*/*.yaml")
    count = allfiles.size


    allfiles.each_with_index do |f, curr|
      form = File.basename(File.dirname(f))
      yaml = YAML::load(File.read(f))
      table = tables[form] # "evaldaten_#{curSem.dirFriendlyName}_#{form}"


      keys = Array.new
      vals = Array.new

      # Get barcode
      keys << "barcode"
      vals << find_barcode_from_basename(File.basename(f, ".yaml")).to_s

      keys << "path"
      vals << f

      yaml.questions.each do |q|
        next if q.type == "text" || q.type == "text_wholepage"
        next if q.db_column.nil?

        if q.db_column.is_a?(Array)
          q.db_column.each_with_index do |a, i|
            # The first answer starts with 1, but i is zero-based.
            # Therefore add 1 everytime to put the results in the
            # right columns.
            vals << (q.value == (i+1).to_s ? 1 : 0).to_s
            keys << a
          end
        else
          vals << (q.value.nil? ? 0 : Integer(q.value)).to_s
          keys << q.db_column
        end
      end

      # If 'update' is specified we delete all existing entries and re-
      # insert them later. Since `path` is UNIQUE insert queries will
      # simply fail if the path already exists.
      # Yes, this is cheap hack.
      $dbh.do("DELETE FROM `#{table}` WHERE `path` = ? ", f) if update

      # "ignore" makes MySQL stop complaining about duplicate unique
      # keys (path in our case)
      q = "INSERT IGNORE INTO `#{table}` ("
      q << keys.join(", ")
      q << ") VALUES ("
      # inserts right amount of question marks for easy
      # escaping
      q << (["?"]*(vals.size)).join(", ")
      q << ")"

      begin
        $dbh.do(q, *vals)
      rescue DBI::DatabaseError => e
        puts
        puts "Failed to insert #{form}/#{File.basename(f)}"
        puts q
        puts "Error code: #{e.err}"
        puts "Error message: #{e.errstr}"
        puts "Error SQLSTATE: #{e.state}"
        puts
        puts "Aborting."
        exit
      end

      print_progress(curr + 1, count)
    end
    puts
    puts "Done!"
  end

  desc "Copies extracted comments into eval directory"
  task :copycomments do
    find = Seee::Config.commands[:find_comment_image_directory] || "find"
    mkdir = Seee::Config.commands[:mkdir_comment_image_directory] || "mkdir"

    puts "Creating folders and copying comments, please wait..."
    system("#{mkdir} -p \"#{Seee::Config.file_paths[:comment_images_public_dir]}/#{curSem.dirFriendlyName}\"")
    path=File.join(File.dirname(__FILE__), "tmp/images")
    system("#{find} \"#{path}\" -name \"*comment.jpg\" -exec cp {} \"#{Seee::Config.file_paths[:comment_images_public_dir]}/#{curSem.dirFriendlyName}/\" \\;")

    puts
    puts "All comment pictures have been copied. If not already done so,"
    puts "you need to make the web-seee know about them. Simply run"
    puts "\trake images:insertcomments"
    puts "for this."
  end
end

namespace :pdf do
  desc "create samples for all available sheets for printing or inclusion. "
  task :samplesheets do
    curSem.forms.each do |f|
      puts "sample for #{f.name}"

      f.languages.each do |l|
         make_sample_sheet(f, l)
      end
    end

    Rake::Task["clean".to_sym].invoke
  end

  desc "makes the result pdfs preliminary"
  task :make_preliminary do
    p = "./tmp/results"
    threads = []
    Dir.glob("#{p}/*.tex") do |d|
      d = File.basename(d)
      next if d.match(/^orl_/)
      threads << Thread.new do
        dn = "orl_" + d.gsub('tex', 'pdf')
        puts "Working on " + d
        `sed 's/title{Lehrevaluation/title{vorl"aufige Lehrevaluation/' #{p}/#{d} | sed 's/Ergebnisse der Vorlesungsumfrage/nicht zur Weitergabe/'  > #{p}/orl_#{d}`
        Rake::Task[("#{p}/" + dn).to_sym].invoke
        `pdftk #{p}/#{dn} background ./helfer/wasserzeichen.pdf output #{p}/preliminary_#{d.gsub('tex', 'pdf')}`
        `rm -f #{p}/#{"orl_" + d.gsub('tex', '*')}`
      end
    end
    threads.each { |t| t.join }
    Rake::Task["clean".to_sym].invoke
  end

  # This is a helper function that will create the result PDF file for a
  # given semester and faculty_id in the specified directory.
  def evaluate(semester_id, faculty_id, directory)
      f = Faculty.find(faculty_id)
      s = Semester.find(semester_id)

      puts "Could not find specified faculty (id = #{faculty_id})" if f.nil?
      puts "Could not find specified smeester (id = #{semester_id})" if s.nil?
      return if f.nil? || s.nil?

      filename = f.longname.gsub(/\s+/,'_').gsub(/^\s|\s$/, "")
      filename << '_'+ s.dirFriendlyName + '.tex'

      File.open(directory + filename, 'w') do |h|
        h.puts(s.evaluate(f))
      end

      puts "Wrote #{directory+filename}"
      Rake::Task[(directory+filename.gsub(/tex$/, 'pdf')).to_sym].invoke
  end

  desc "create report pdf file for a given semester and faculty (leave empty for: sem = current, fac = all)"
  task :semester, :semester_id, :faculty_id, :needs => ['pdf:samplesheets'] do |t, a|
    sem = a.semester_id.nil? ? curSem.id : a.semester_id

    dirname = './tmp/results/'
    FileUtils.mkdir_p(dirname)

    # we have been given a specific faculty, so evaluate it and exit.
    if not a.faculty_id.nil?
      evaluate(sem, a.faculty_id, dirname)
      exit
    end

    # no faculty specified, just find all and process them in parallel.
    Faculty.find(:all).each do |f|
      job = fork { exec "rake pdf:semester[#{sem},#{f.id}]" }
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
      make_pdf_for(s, cp, dirname)
    end

    Rake::Task["clean".to_sym].invoke
  end

  desc "Create How Tos"
  task :howto, :needs => 'db:connect' do
    saveto = './tmp/howtos/'
    FileUtils.mkdir_p(saveto)

    dirname = Seee::Config.file_paths[:forms_howto_dir]
    # Escape for TeX
    dirname << Semester.find(:last).dirFriendlyName.gsub('_', '\_')
    threads = []
    Dir.glob("./doc/howto_*.tex").each do |f|
      threads << Thread.new do
        data = File.read(f).gsub(/§§§/, dirname)
        file = saveto + File.basename(f)
        File.open(file, "w") { |x| x.write data }
        Rake::Task[(file.gsub(/\.tex$/, ".pdf")).to_sym].invoke
        File.delete(file)
      end
    end
    threads.each { |t| t.join }
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
    `cd tmp && ./../helfer/physik_tutoren.rb`
    require 'date'
    Date.today.strftime("Schau mal in tmp/%Y-%m-%d Tutoren Physik.txt")
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


namespace :crap do
    desc "does not print non-existing ranking that does not exist"
    task :rank, :needs => 'db:connect' do
        s = curSem.title.gsub(" ", "_")
        # One query to RANK THEM ALL!
        query = $dbh.prepare("(SELECT AVG(v22) as note, COUNT(v22) as num, barcode  FROM `evaldaten_#{s}_0` GROUP BY `barcode`) UNION ALL (SELECT AVG(v22) as note, COUNT(v22) as num, barcode  FROM `evaldaten_#{s}_2` GROUP BY `barcode`) ORDER BY note ASC")
        query.execute()
        puts "Note\tStimmen\tVorlesung (Dozent)"
        while row = query.fetch() do
            cp = CourseProf.find(row[2])
            print row[0]
            print "\t"
            print row[1].to_s.rjust(5)
            print "\t"
            print cp.course.title.ljust(60)
            print "\t("
            print cp.prof.fullname
            puts ")"
        end
    end
end

namespace :summary do
  def fixCommonTeXErrors(code)
    # _ -> \_, '" -> "', `" -> "`
    code = code.gsub(/([^\\])_/, '\1\\_').gsub(/`"/,'"`').gsub(/'"/, '"\'')
    # correct common typos
    code = code.gsub("{itemsize}", "{itemize}").gsub("/begin{", "\\begin{")
    code = code.gsub("/end{", "\\end{").gsub("/item ", "\\item ")
    code = code.gsub("\\beign", "\\begin").gsub(/[.]{3,}/, "\\dots ")
    code
  end

  def warnAboutCommonTeXErrors(code)
    msg = []
    msg << "Unescaped %-sign?" if code.match(/[^\\]%/)

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
    head = praeambel("Blaming Someone For Bad LaTeX")
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
