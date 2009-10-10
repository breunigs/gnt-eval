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
end

rule '.pdf' => '.tex' do |t|
  3.times do
    `pdflatex -output-directory #{File.dirname(t.source)} #{File.basename(t.source)}`
  end
  puts "Wrote #{t.name}"
end
