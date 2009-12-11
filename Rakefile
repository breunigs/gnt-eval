require 'lib/ext_requirements.rb'
require 'dbi'
require 'pp'

require 'rake/clean'

CLEAN.include('tmp/*.log', 'tmp/*.out', 'tmp/*.aux', 'tmp/*.toc')


namespace :db do 
  task :connect do 
    $dbh = DBI.connect('DBI:Mysql:eval', 'eval', 'E-Wahl')
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
      filename = (f + ' ' + s.title).gsub(' ','_') + '.tex'  

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

          tutoren = cp.course.tutors.sort{ |a,b| a.id <=> b.id }.map{ |t| t.abbr_name } + (["\\ "] * (30-cp.course.tutors.count))
        
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
end

rule '.pdf' => '.tex' do |t|
  # According to Jasper calling pdflatex once is sufficient
  1.times do
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
