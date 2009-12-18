# -*- coding: utf-8 -*-
require 'action_mailer'
require 'web/config/boot'
require 'lib/ext_requirements.rb'
require 'dbi'
require 'pp'

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


namespace :db do
  task :connect do
    $dbh = DBI.connect('DBI:Mysql:eval', 'eval', 'E-Wahl')
  end
end

namespace :images do 
  desc "Work on the .tif's in directory and sort'em to tmp/images/..."
  task :sortandalign, :directory do |t, d|
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
    desc "fixes the LaTeX output to be conform with the yaml specification"
    task :yamlfix, :file do |t, a|
        `cd "#{File.dirname(a.file)}" && ../pest/latexfix.rb "#{File.basename(a.file)}" && rm "#{File.basename(a.file)}"`
        puts "Wrote #{File.basename(a.file)}.yaml"
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
      # first: the barcode
      filename = dirname + cp.barcode
      `barcode -b "#{cp.barcode}" -g 80x30 -u mm -e EAN -n -o #{filename}.ps && ps2pdf #{filename}.ps #{filename}.pdf && pdfcrop #{filename}.pdf && rm #{filename}.ps && rm #{filename}.pdf && mv -f #{filename}-crop.pdf #{dirname}barcode.pdf`

      # second: the form
      filename = dirname + [cp.course.title, cp.prof.fullname, cp.course.students.to_s + 'pcs'].join(' - ')
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
      Rake::Task[("pest:yamlfix").to_sym].invoke((filename + '.posout'))
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
