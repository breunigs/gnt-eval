# -*- coding: utf-8 -*-

# some config stuff

# Increase density and disable all other barcodes for perf wins
$zbarCmd = " --set ean13.disable=1 --set upce.disable=1 --set isbn10.disable=1 --set upca.disable=1 --set isbn13.disable=1 --set i25.disable=1 --set code39.disable=1 --set code128.disable=1 --set y-density=4 "

$pdflatex = "/home/jasper/texlive/2009/bin/x86_64-linux/pdflatex"
# -halt-on-error: stops TeX after the first error
# -file-line-error: displays file and line where the error occured
# -draftmode: doesn't create PDF, which speeds up TeX. Still does
#             syntax-checking and toc-creation
# -interaction=nonstopmode prevents from asking for stuff on the
#             console which regularily occurs for missing packages
$pdflatexFastCmd = "-halt-on-error -file-line-error -draftmode -interaction=nonstopmode"
$pdflatexRealCmd = "-halt-on-error -file-line-error"

# you probably want to hack the :copycomments task and specify where
# to copy the images so they may be found



require 'rubygems'
require 'action_mailer'
require 'web/config/boot'
require 'lib/ext_requirements.rb'
require 'dbi'
require 'pp'

# need for parsing yaml into database
require 'yaml'

# needed for image manipulations
require 'RMagick'
require 'ftools'

include Magick


require 'rake/clean'
CLEAN.include('tmp/*.log', 'tmp/*.out', 'tmp/*.aux', 'tmp/*.toc', 'tmp/*/*.log', 'tmp/*/*.out', 'tmp/*/*.aux', 'tmp/*/*.toc', 'tmp/blame.tex')

$curSem = Semester.find(:all).find{ |s| s.now? }


def word_wrap(txt, col = 80)
    txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
      "\\1\\3\n")
end

def find_barcode(filename)
  r = `./helfer/zbarimg_hackup/zbarimg #{$zbarCmd} #{filename}`
  if not r.empty?
    return r.strip.match(/^([0-9]+)/)[1].to_i
  else
    return nil
  end
end

def find_barcode_from_basename(basename)
    basename.to_s.sub(/^.*_/, '').to_i
end

# FIXME: we should really create a "form" class that collects all these information
# [vorlesung, spezial, englisch, seminar]
def tex_head_for(form)
  '\\' + ['', '', 'eng', ''][form] + 'kopf{' + ['1', '0', '1', '0'][form] + '}'
end

def tex_questions_for(form)
  ['\vorlesungsfragen', '\vorlesungsfragen', '\vorlesungenglisch', '\seminarfragen'][form]
end

def tex_none(form)
  ['keine', 'keine', 'none', ''][form]
end

def make_sample_sheet(form, hasTutors)
  dir = "tmp/sample_sheets/"
  File.makedirs(dir)
  # Barcode
  filename = dir + "barcode"
  `barcode -b "00000000" -g 80x30 -u mm -e EAN -n -o #{filename}.ps && ps2pdf #{filename}.ps #{filename}.pdf && pdfcrop #{filename}.pdf && rm #{filename}.ps && rm #{filename}.pdf && mv -f #{filename}-crop.pdf #{dir}barcode.pdf`
  # TeX
  filename = dir + "sample_" + form.to_s
  File.open(filename + ".tex", "w") do |h|
    h << '\documentclass[ngerman]{eval}' + "\n"
    h << '\dozent{Fachschaft MathPhys}' + "\n"
    h << '\vorlesung{Musterbogen für die Evaluation}' + "\n"
    h << '\semester{'+ ($curSem.title) +'}' + "\n"

    h << '\tutoren{ \mmm[1][Mustafa Mustermann] Mustafa Mustermann & \mmm[2][Fred Nurk] Fred Nurk & \mmm[3][Ashok Kumar] Ashok Kumar & \mmm[4][Juan Pérez] Juan Pérez & \mmm[5][Jakob Mierscheid] Jakob Mierscheid\\\\ \mmm[6][Iwan Iwanowitsch] Iwan Iwanowitsch & \mmm[7][Pierre Dupont] Pierre Dupont & \mmm[8][John Smith] John Smith & \mmm[9][Eddi Exzellenz] Eddi Exzellenz & \mmm[10][Joe Bloggs] Joe Bloggs\\\\ \mmm[11][John Doe] John Doe & \mmm[12][\ ] \  & \mmm[13][\ ] \  & \mmm[14][\ ] \  & \mmm[15][\ ] \  \\\\ \mmm[16][\ ] \ & \mmm[17][\ ] \  & \mmm[18][\ ] \  & \mmm[19][\ ] \  & \mmm[20][\ ] \ \\\\ \mmm[21][\ ] \  & \mmm[22][\ ] \  & \mmm[23][\ ] \  & \mmm[24][\ ] \  & \mmm[25][\ ] \ \\\\ \mmm[26][\ ] \  & \mmm[27][\ ] \  & \mmm[28][\ ] \  & \mmm[29][\ ] \  & \mmm[30][\ keine] \ keine\\ }' if hasTutors

    h << '\begin{document}' + "\n"
    h << tex_head_for(form) + "\n\n\n"
    h << tex_questions_for(form) + "\n"
    h << '\end{document}'
  end

  puts "Wrote #{filename}.tex"
  Rake::Task[(filename + '.pdf').to_sym].invoke
end

def escapeForTeX(string)
  # escapes & and % signs if not already done so
  string.gsub(/\\?&/, '\\\&').gsub(/\\?%/, '\\\%')
end

# Creates form PDF file for given semester and CourseProf
def make_pdf_for(s, cp, dirname)
    # first: the barcode
    filename = dirname + cp.barcode
    `barcode -b "#{cp.barcode}" -g 80x30 -u mm -e EAN -n -o #{filename}.ps && ps2pdf #{filename}.ps #{filename}.pdf && pdfcrop #{filename}.pdf && rm #{filename}.ps && rm #{filename}.pdf && mv -f #{filename}-crop.pdf #{dirname}barcode.pdf`

    # second: the form
    filename = dirname + cp.get_filename.gsub(/\s+/,' ').gsub(/^\s|\s$/, "")
    File.open(filename + '.tex', 'w') do |h|
    h << '\documentclass[ngerman]{eval}' + "\n"
    h << '\dozent{' + escapeForTeX(cp.prof.fullname) + '}' + "\n"
    h << '\vorlesung{' + escapeForTeX(cp.course.title) + '}' + "\n"
    h << '\semester{' + escapeForTeX(s.title) + '}' + "\n"
    # FIXME: insert check for tutors.empty? and also sort them into a different directory!
    if cp.course.form != 3
      none = tex_none(cp.course.form)
      h << '\tutoren{' + "\n"

      tutoren = cp.course.tutors.sort{ |a,b| a.id <=> b.id }.map{ |t| t.abbr_name } + (["\\ "] * (29-cp.course.tutors.count)) +  ["\\ #{none}"]

      tutoren.each_with_index do |t, i|
        t = escapeForTeX(t)
        h << '\mmm[' + (i+1).to_s + '][' + t + '] ' + t + ( (i+1)%5==0 ? '\\\\' + "\n" : ' & ' )
      end

      h << '}' + "\n"
    end
    h << '\begin{document}' + "\n"
    h << tex_head_for(cp.course.form) + "\n\n\n"
    h << tex_questions_for(cp.course.form) + "\n"
    h << '\end{document}'
    end
    puts "Wrote #{filename}.tex"
    Rake::Task[(filename + '.pdf').to_sym].invoke

    `./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
end

# Prints the current progress to the console without advancing one line
# val: currently processed item
# max: amount of items to process
def printProgress(val, max)
      percentage = (val.to_f/max.to_f*100.0).to_i.to_s.rjust(3)
      current = val.to_s.rjust(max.to_s.size)
      print "\r#{percentage}% (#{current}/#{max})"
      STDOUT.flush
end

# automatically calls rake -T when no task is given
task :default do
  puts "Choose your destiny:"
  # remove first line because no one cares about the current directory
  d = `rake -T`.split("\n")
  d.shift
  puts d.join("\n")
end

namespace :db do
  task :connect do
    $dbh = DBI.connect('DBI:Mysql:eval', 'eval', 'E-Wahl')
  end
end

namespace :images do

  desc "(6) Insert comment pictures from YAML/jpg in directory. Leave directory empty for useful defaults."
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
      tname = basename + '-tutorcomment.jpg'
      if File.exists?(File.join(curdir, tname)) && tpics.select { |x| x.basename == tname }.empty?
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
            p.basename = basename + '-tutorcomment.jpg'
            p.save
            #~ puts "Inserted #{p.basename} for #{tutors[tutnum-1].abbr_name} as #{p.id}"
          end
        else
          $stderr.print "\rDid nothing with #{basename}, tutnum is 0 (no choice made)\n"
        end
      end

      # finds comments for uhm… seminar sheet maybe?
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
      cname = basename + '-vorlcomment.jpg'
      if File.exists?(File.join(curdir, cname)) && cpics.select { |x| x.basename == cname }.empty?
        barcode = find_barcode_from_basename(basename)

        course_prof = CourseProf.find(barcode)

        p = CPic.new
        p.course_prof = course_prof
        p.basename = basename + '-vorlcomment.jpg'
        p.save
        #~ puts "Inserted #{p.basename} for #{course_prof.prof.fullname}: #{course.title} as #{p.id}"
      end

      printProgress(curr+1, allfiles.size)
    end # Dir glob

    puts
    puts "Please ensure that all comment pictures have been supplied to"
    puts "\t/home/eval/public_html/.comments/#{$curSem.dirfriendly_title}"
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
      files.each_with_index do |f, curr|
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

        form = CourseProf.find(barcode).course.form
        File.makedirs("tmp/images/#{form}")
        File.move(f, File.join("tmp/images/#{form}", basename + '_' + barcode.to_s + '.tif'))

        #~ puts "Moved to #{form}/#{basename} (#{barcode})"
        printProgress(curr+1, files.size)
      end
    end
  end
end

namespace :print do
  ## Nach Eval-Datum sortieren! (erleichtert dann das Eintüten)
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
  desc '(2) Finds all different forms for each folder and saves the form file as tmp/images/[form id].yaml'
  task :getyamls, :needs => 'db:connect' do |t|
    # FIXME: This can surely be done simpler by directly finding
    # a form for the current semester
    Dir.glob("./tmp/images/[0-9]*/").each do |f|
      Dir.glob("#{f}*.tif") do |y|
        barcode = find_barcode_from_basename(File.basename(y, ".tif")) #find_barcode(y)/10
        cp = CourseProf.find(barcode)
        make_pdf_for(cp.course.semester, cp, f)
        `mv -f "#{f + cp.get_filename}.yaml" "#{f}../#{File.basename(f)}.yaml"`
        break
      end
    end
  end

  # note: this is called automatically by yaml2db
  desc "Create db tables for each form for the available YAML files"
  task :createtables, :needs => 'db:connect' do
    Dir.glob("./tmp/images/[0-9]*.yaml").each do |f|
        yaml = YAML::load(File.read(f))
        name = "evaldaten_" + $curSem.dirFriendlyName + '_' + File.basename(f, ".yaml")

        # Note that the barcode is only unique for each CourseProf, but
        # not for each sheet. That's why path is used as unique key.
        q = "CREATE TABLE IF NOT EXISTS `" + name + "` ("
        q << "`path` VARCHAR(255) CHARACTER SET utf8 NOT NULL UNIQUE, "
        q << "`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT, "
        q << "`barcode` INT(11) default NULL, "

        yaml.questions.each do |quest|
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

        puts "Creating #{name}"
        $dbh.do(q)
    end
  end

  desc "(3) Evaluates all sheets in ./tmp/images/"
  task :omr do
    Dir.glob("./tmp/images/[0-9]*.yaml").each do |f|
      puts "Now processing #{f}"
      bn = File.basename(f, ".yaml")
      system('./pest/omr.rb -s "'+f+'" -p "./tmp/images/'+bn+'" -c 2')
    end
  end

  desc "(4) Correct invalid sheets"
  task :correct do
      `./pest/fix.rb ./tmp/images/`
  end

  desc "(5) Copies YAML data into database. Append update only, if you really want to re-insert existing YAMLs into the database."
  task :yaml2db, :update, :needs => ['db:connect', 'pest:createtables'] do |t,a|

    update = !a.update.nil? && a.update == "update"
    puts "Will be updating already existing entries." if update

    allfiles = Dir.glob("./tmp/images/[0-9]*/*.yaml")
    count = allfiles.size

    allfiles.each_with_index do |f, curr|
      form = File.basename(File.dirname(f))
      yaml = YAML::load(File.read(f))
      table = "evaldaten_#{$curSem.dirFriendlyName}_#{form}"

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
      $dbh.do("DELETE FROM `#{table}` WHERE `path` = ?", f) if update

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

      printProgress(curr + 1, count)
    end
    puts
    puts "Done!"
  end

  desc "Copies extracted comments into eval directory"
  task :copycomments do
    puts "Creating folders and copying comments, please wait..."
    # FIXME. This shouldn't be specified here
    system("login_gruppe_home eval mkdir -p \"/home/eval/public_html/.comments/#{$curSem.dirFriendlyName}\"")
    path=File.join(File.dirname(__FILE__), "tmp/images")
    system("login_gruppe_home eval find \"#{path}\" -name \"*comment.jpg\" -exec cp {} \"/home/eval/public_html/.comments/#{$curSem.dirFriendlyName}/\" \\;")

    puts
    puts "All comment pictures have been copied. If not already done so,"
    puts "you need to make the web-seee know about them. Simply run"
    puts "\trake images:insertcomments"
    puts "for this."
23  end
end

namespace :pdf do
  desc "create samples for all available sheets for printing or inclusion. "
  task :samplesheets do
    0.upto(3) do |i|
      make_sample_sheet(i, (i == 0 || i == 2))
    end

    Rake::Task["clean".to_sym].invoke
  end

  desc "makes the result pdfs preliminary"
  task :make_preliminary do
    Dir.glob("./tmp/[^orl]*[WS]S*.tex") do |d|
      d = File.basename(d)
      dn = "orl_" + d.gsub('tex', 'pdf')
      puts "Working on " + d
      `sed 's/title{Lehrevaluation/title{vorl"aufige Lehrevaluation/' ./tmp/#{d} | sed 's/Ergebnisse der Vorlesungsumfrage/nicht zur Weitergabe/'  > ./tmp/orl_#{d}`
      Rake::Task[("tmp/" + dn).to_sym].invoke
      `pdftk ./tmp/#{dn} background ./helfer/wasserzeichen.pdf output ./tmp/preliminary_#{d.gsub('tex', 'pdf')}`
      `rm -f ./tmp/orl_*`
    end
  end

  desc "create pdf-file for a certain semester (leave empty for current)"
  task :semester, :semester_id, :needs => ['db:connect', 'pdf:samplesheets'] do |t, a|
    sem = a.semester_id.nil? ? $curSem.id : a.semester_id
    s = Semester.find(sem)
    Faculty.find(:all).each_with_index do |f,i|
      dirname = './tmp/'
      `mkdir tmp` unless File.exists?('./tmp/')
      filename = f.longname.gsub(/\s+/,'_').gsub(/^\s|\s$/, "") +'_'+ s.dirFriendlyName + '.tex'

      File.open(dirname + filename, 'w') do |h|
        h.puts(s.evaluate(f, $dbh))
      end

      puts "Wrote #{dirname+filename}"
      Rake::Task[(dirname+filename.gsub('tex', 'pdf')).to_sym].invoke
    end
  end

  desc "create pdf-form-files corresponding to each corse and prof (leave empty for current semester)"
  task :forms, :semester_id, :needs => 'db:connect' do |t, a|
    `mkdir tmp` unless File.exists?('./tmp/')
    sem = a.semester_id.nil? ? $curSem.id : a.semester_id
    s = Semester.find(sem)
    dirname = './tmp/'
    CourseProf.find(:all).find_all { |x| x.course.semester == s }.each do |cp|
        make_pdf_for(s, cp, dirname)
    end

    Rake::Task["clean".to_sym].invoke
  end

  desc "Create How Tos"
  task :howto, :needs => 'db:connect' do
    saveto = './tmp/'
    dirname = "/home/eval/forms/"
    # Escape for TeX
    dirname << Semester.find(:last).dirFriendlyName.gsub('_', '\_')
    Dir.glob("./doc/howto_*.tex").each do |f|
        texdata = File.read(f).gsub(/§§§/, dirname)
        tex = File.open(saveto + File.basename(f), "w")
        tex.write(texdata)
        tex.close
        Rake::Task[(saveto + File.basename(f).gsub(/\.tex$/, ".pdf")).to_sym].invoke
        File.delete(saveto + File.basename(f))
    end
    Rake::Task["clean".to_sym].invoke
  end

  desc "Create tutor blacklist for current semester"
  task :blacklist, :needs => 'db:connect' do
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
    tutors = $curSem.courses.collect { |c| c.tutors }.flatten.sort { |x,y| x.abbr_name <=> y.abbr_name }
    tutors.each do |t|
      puts [t.abbr_name, t.course.title[0,20], t.profit($dbh).rtt, t.teacher($dbh).rtt, t.competence($dbh).rtt, t.preparation($dbh).rtt, t.boegenanzahl($dbh)].join(' & ') + '\\\\'
    end
  end
end

namespace :helper do
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

  desc "Generate lovely HTML output for our static website"
  task :static_output do
    puts "<ul>"
    $curSem.courses.sort {|x,y| x.title <=> y.title }.each do |c|
      tuts = c.tutors.collect{ |t| t.abbr_name }
      profs = c.profs.collect{ |t| t.fullname }
      hasEval = c.fs_contact_addresses.empty? ? "&nbsp;" : "&#x2713;"
      print "<li><span class=\"evalcheckmark\">#{hasEval}</span> <strong>#{c.title}</strong>"
      print "; <em>#{profs.join(', ')}</em>" unless profs.empty?
      print "; #{c.description}" unless c.description.empty?
      print "<br/><span class=\"evalcheckmark\">&nbsp;</span> Tutoren: #{tuts.join(', ')}" unless tuts.empty?
      puts "<br/>&nbsp;</li>"
    end
    puts "</ul>"
  end

  desc "Generate crappy output sorted by day for simplified packing"
  task :packing_sheet do
    crap = '<meta http-equiv="content-type" content=
  "text/html; charset=utf-8"><style> td { border-right: 1px solid #000; } .odd { background: #eee; }</style><table>'
    # used for sorting
    h = Hash["mo", 1, "di", 2, "mi", 3, "do", 4, "fr", 5]
    # used for counting
    count = Hash["mo", 0, "di", 0, "mi", 0, "do", 0, "fr", 0]
    d = $curSem.courses.sort do |x,y|
      a = x.description.strip.downcase
      b = y.description.strip.downcase

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
       count[c.description.strip[0..1].downcase] += 1
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
        s = $curSem.title.gsub(" ", "_")
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
    $curSem.courses.each do |c|
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

    `cd ./tmp/ && #{$pdflatex} #{$pdflatexFastCmd} blame.tex 2>&1`
    $?
  end

  desc "find comment fields with broken LaTeX code"
  task :blame do
    $curSem.courses.each_with_index do |c, i|
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
      printProgress(i + 1, $curSem.courses.size)
    end
    puts "\nIf there were errors you might want to try"
    puts "\trake summary:fixtex"
    puts "first before fixing manually."
  end
end

rule '.pdf' => '.tex' do |t|
    filename="\"#{File.basename(t.source)}\""
    texpath="cd \"#{File.dirname(t.source)}\";#{$pdflatex}"


    # run it once fast, to see if there are any syntax errors in the
    # text and create first-run-toc
    err = `#{texpath} #{$pdflatexFastCmd} #{filename} 2>&1`
    if $?.to_i != 0
        puts "="*60
        puts err
        puts "\n\n\nERROR WRITING: #{t.name}"
        puts "EXIT CODE: #{$?}"
        puts "="*60
        puts "Running 'rake summary:fixtex' or 'rake summary:blame' might help."
        exit
    end

    # run it fast a second time, to get /all/ references correct
    `#{texpath} #{$pdflatexFastCmd} #{filename} 2>&1`
    # now all references should have been resolved. Run it a last time,
    # but this time also output a pdf
    `#{texpath} #{$pdflatexRealCmd} #{filename} 2>&1`

    if $?.to_i == 0
        puts "Wrote #{t.name}"
    else
        puts "Some other error occured. It shouldn't be TeX-related, as"
        puts "it already passed one run. Well, happy debugging."
    end
end
