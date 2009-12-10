require 'lib/ext_requirements.rb'
require 'dbi'

require 'rake/clean'

CLEAN.include('tmp/*.log', 'tmp/*.out', 'tmp/*.aux', 'tmp/*.toc')


namespace :db do 
  task :connect do 
    $dbh = DBI.connect('DBI:Mysql:eval', 'eval', 'E-Wahl')
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
    dirname = './tmp/forms/'
    CourseProf.find(:all).find_all { |x| x.course.semester == s }.each do |cp|
      # first: the barcode
      filename = dirname + cp.barcode
      `barcode -b "#{cp.barcode}" -g 80x30 -u mm -e EAN -n -o #{filename}.ps && ps2pdf #{filename}.ps #{filename}.pdf && pdfcrop #{filename}.pdf && rm #{filename}.ps && rm #{filename}.pdf && mv #{filename}-crop.pdf #{dirname}barcode.pdf`
      
      # second: the form
      filename = dirname + [cp.course.title, cp.prof.fullname, cp.course.students.to_s + 'pcs'].join(' - ') 
      File.open(filename + '.tex', 'w') do |h|
        h << '\documentclass[ngerman]{eval}' + "\n"
        h << '\dozent{' + cp.prof.fullname + '}' + "\n"
        h << '\vorlesung{' + cp.course.title + '}' + "\n"
        h << '\semester{' + s.title + '}' + "\n"
        if cp.course.tutors.count < 30
          h << '\tutoren{' + "\n"

          tutoren = cp.course.tutors.map{ |t| t.abbr_name }.sort + (["--"] * (30-cp.course.tutors.count))
        
          tutoren.each_with_index do |t, i|
            h << '\mmm[' + (i+1).to_s + '][' + t + '] ' + t + ( (i+1)%5==0 ? '\\\\' + "\n" : ' & ' )
          end

          h << '}' + "\n"
        end
        h << '\begin{document}' + "\n"
        h << '\kopf{1}' + "\n\n"
        h << '\vorlesungsfragen' + "\n"
        h << '\end{document}'
      end
      puts "Wrote #{filename}.tex"
#      Rake::Task[(filename + '.pdf').to_sym].invoke
    end

  end
end

rule '.pdf' => '.tex' do |t|
  3.times do
    `/home/jasper/texlive/2009/bin/x86_64-linux/pdflatex -output-directory #{File.dirname(t.source)} #{File.basename(t.source)}`
  end
  puts "Wrote #{t.name}"
end
