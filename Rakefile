# -*- coding: utf-8 -*-
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

CLEAN.include('tmp/*.log', 'tmp/*.out', 'tmp/*.aux', 'tmp/*.toc')


def word_wrap(txt, col = 80)
    txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
      "\\1\\3\n")
end

def find_page(filename)
  r = `zbarimg --xml --set ean13.disable=1 #{filename} 2>/dev/null`
  if not r.empty?
    return r.strip.match(/^.*num='(\d)'.*/m)[1].to_i
  else
    return nil
  end
end

def find_barcode(filename)
  r = `zbarimg --set ean13.disable=1 #{filename} 2>/dev/null`
  if not r.empty?
    return r.strip.match(/^.*:(.*)$/)[1].to_i
  else
    return nil
  end
end

# Creates form PDF file for given semester and CourseProf
def make_pdf_for(s, cp, dirname)
    # first: the barcode
    filename = dirname + cp.barcode
    `barcode -b "#{cp.barcode}" -g 80x30 -u mm -e EAN -n -o #{filename}.ps && ps2pdf #{filename}.ps #{filename}.pdf && pdfcrop #{filename}.pdf && rm #{filename}.ps && rm #{filename}.pdf && mv -f #{filename}-crop.pdf #{dirname}barcode.pdf`

    # second: the form
    filename = dirname + cp.get_filename
    File.open(filename + '.tex', 'w') do |h|
    h << '\documentclass[ngerman]{eval}' + "\n"
    h << '\dozent{' + cp.prof.fullname + '}' + "\n"
    h << '\vorlesung{' + cp.course.title + '}' + "\n"
    h << '\semester{' + s.title + '}' + "\n"
    if cp.course.form != 3
      h << '\tutoren{' + "\n"

      tutoren = cp.course.tutors.sort{ |a,b| a.id <=> b.id }.map{ |t| t.abbr_name } + (["\\ "] * (29-cp.course.tutors.count)) + ["\\ keine"]

      tutoren.each_with_index do |t, i|
        h << '\mmm[' + (i+1).to_s + '][' + t + '] ' + t + ( (i+1)%5==0 ? '\\\\' + "\n" : ' & ' )
      end

      h << '}' + "\n"
    end
    h << '\begin{document}' + "\n"
    h << '\\' + ['', '', 'eng', ''][cp.course.form] + 'kopf{' + ['1', '1', '1', '0'][cp.course.form] + '}' + "\n\n\n" # [vorlesung, spezial, englisch, seminar]
    h << ['\vorlesungsfragen', '\vorlesungsfragen', '\vorlesungenglisch', '\seminarfragen'][cp.course.form] + "\n"
    h << '\end{document}'
    end
    puts "Wrote #{filename}.tex"
    Rake::Task[(filename + '.pdf').to_sym].invoke

    `./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
end


namespace :db do
  task :connect do
    $dbh = DBI.connect('DBI:Mysql:eval', 'eval', 'E-Wahl')
  end
end

namespace :images do 
  
  desc "Insert tutor comment pictures from YAML/jpg in directory." +
       "Please supply all images to" +
       " /home/eval/public_html/.tutcomments/#{Semester.find(:all).find{ |s| s.now? }.dirfriendly_title}"
  task :inserttutorcomments, :directory do |t, d|
    Dir.glob(File.join(d.directory, '*.yaml')) do |f|
      basename = File.basename(f, '.yaml')
      if File.exists?(File.join(d.directory, basename + '-tutorcomment.jpg'))
        scan = YAML::load(File.read(f))
        tutnum = scan.questions.find{ |q| q.db_column == "v1" }.value.to_i
        barcode = basename.to_s.sub(/^.*_/, '').to_i

        course = CourseProf.find(barcode).course

        # first cross is 1 !
        if tutnum > 0
          tutors = course.tutors.sort{ |a,b| a.id <=> b.id }
          if tutnum > tutors.count
            puts "Did nothing with #{basename}, #{tutnum} > #{tutors.count}"
          else
            p = Pic.new
            p.tutor_id = tutors[tutnum-1].id
            p.basename = basename + '-tutorcomment.jpg'
            p.save
            puts "Inserted #{p.basename} for #{tutors[tutnum-1].abbr_name} as #{p.id}"
          end
        else
          puts "Did nothing with #{basename}, tutnum is #{tutnum}"
        end
      end
    end
  end
  
  desc "Work on the .tif's in directory and sort'em to tmp/images/..."
  task :sortandalign, :directory do |t, d|
    raise "This is defunctional and has serious memory leakage"
    Dir.glob(File.join(d.directory, '*.tif')) do |f|
      basename = File.basename(f, '.tif')
      pages = ImageList.new(f)

      changed_smth = nil

      barcode = (find_barcode(f).to_f / 10).floor.to_i
      page = find_page(f)

      if barcode.nil? || page.nil? || (not CourseProf.exists?(barcode))
        puts "bizarre #{basename}, exiting"
        File.makedirs('tmp/images/bizarre')
        File.copy(f, 'tmp/images/bizarre')
        next
      end

      # is the barcode on the first page
      if page != 0
        pages.reverse!
        puts "switched #{basename}"
      end

      # is the barcode on the upper half of the first page?
      tmp_filename = "/tmp/bgndrhn_#{basename}_#{Time.now.to_i}.tif"

      pages[0].crop(0, 0, 2480, 1000).write(tmp_filename)

      # the barcode is not at the top
      if find_barcode(tmp_filename).nil?
        pages.map! { |i| i.rotate(180) }
        puts "flipped #{basename}"
      end

      File.delete(tmp_filename)

      form = CourseProf.find(barcode).course.form
      
      File.makedirs("tmp/images/#{form}")
      
      pages.write(File.join("tmp/images/#{form}", basename + '_' + barcode.to_s + '.tif'))

      puts "Wrote #{form}/#{basename} (#{barcode})"

    end
  end
end

namespace :print do
  ## Nach Datum sortieren!
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
  desc '(1) Finds all different forms for each folder and puts the form file into tmp/images/[form id]/'
  task :getyamls, :needs => 'db:connect' do |t|
    s = Semester.find(:all).find{ |s| s.now? }
    # FIXME: This can surely be done simpler by directly finding
    # a form for the current semester
    Dir.glob("./tmp/images/[0-9]*/").each do |f|
      Dir.glob("#{f}*.tif") do |y|
        barcode = find_barcode(y)/10
        cp = CourseProf.find(barcode)
        make_pdf_for(s, cp, f)
        `mv -f "#{f + cp.get_filename}.yaml" "#{f}../#{File.basename(f)}.yaml"`
        break
      end
    end
  end
  
  desc "(2) Create db tables for each form for the available YAML files"
  task :createtables, :needs => 'db:connect' do |t|
    Dir.glob("./tmp/images/[0-9]*.yaml").each do |f|
        yaml = YAML::load(File.read(f))
        s = Semester.find(:all).find{ |s| s.now? }
        name = "evaldaten_" + s.dirFriendlyName + '_' + File.basename(f, ".yaml")
        
        q = "CREATE TABLE IF NOT EXISTS `" + name + "` ("
        q += "`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT, "
        q += "`dateiname` varchar(256) default NULL, "
        q += "`bearbeiter` varchar(80) default NULL, "
        q += "`dozent` varchar(256) default NULL, "
        q += "`vorlesung` varchar(256) default NULL, "
        
        yaml.questions.each do |quest|
            if quest.db_column.is_a?(Array)
                quest.db_column.each do |a|
                    q += "`" + a + "` SMALLINT(6) UNSIGNED, "
                end
            else
                q += '`'+ quest.db_column.to_s + "` SMALLINT(6) UNSIGNED, "
            end
        end
        q += "PRIMARY KEY (id)"
        q += ");"
      
        puts "Creating #{name}"
        $dbh.execute(q)
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
  
  desc "(4)"
  task :foo do 
    raise "not implemented"
  end
end

namespace :pdf do
  desc "create pdf-file for a certain semester"
  task :semester, :semester_id, :needs => 'db:connect' do |t, a|
    s = Semester.find(a.semester_id)
    ['Mathematik', 'Physik'].each_with_index do |f,i|
      dirname = './tmp/'
      `mkdir tmp` unless File.exists?('./tmp/')
      filename = f.gsub(' ','_') +'_'+ s.dirFriendlyName + '.tex'

      File.open(dirname + filename, 'w') do |h|
        h.puts(s.evaluate(i, $dbh))
      end

      puts "Wrote #{dirname+filename}"
      Rake::Task[(dirname+filename.gsub('tex', 'pdf')).to_sym].invoke
    end
  end

  desc "create pdf-form-files corresponding to blabla"
  task :forms, :semester_id, :needs => 'db:connect' do |t, a|
    s = Semester.find(a.semester_id)
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
end

rule '.pdf' => '.tex' do |t|
  3.times do
    err = `cd "#{File.dirname(t.source)}";/home/jasper/texlive/2009/bin/x86_64-linux/pdflatex -halt-on-error "#{File.basename(t.source)}" 2>&1`
    if $?.to_i != 0
      puts "="*50
      puts err
      break
    end
  end
  if $?.to_i == 0
    puts "Wrote #{t.name}"
  else
    puts "ERROR WRITING: #{t.name}"
    puts "EXIT CODE: #{$?}"
    puts "="*50
  end
end
