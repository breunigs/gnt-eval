#!/usr/bin/env ruby

account = "re9"
server = "kde05.urz.uni-heidelberg.de"
homepath = "/Home/#{account}"
ssh = "ssh -o \"ControlPath=/tmp/print_forms_%r@%h:%p\" #{account}@#{server}"

mypath=File.dirname(__FILE__)

RAILS_ROOT = mypath + '/../web'
class Rails
  def self.root
    RAILS_ROOT
  end
end
require mypath + '/../web/app/lib/ext_requirements.rb'

semester = Semester.find(:all).find { |s| s.now? }.title.gsub(/\s+/, "_").scan(/[-_a-z0-9]+/i).join

if semester.nil?
  puts "Could not detect current semester. Exiting."
  exit 1
end

sheets = 0
forms = {}

puts "The following forms will be printed:"
Dir.glob(mypath + "/../tmp/forms/*pcs.pdf") do |f|
  next if File.basename(f).start_with?(" multiple")
  count = f.match(/.*\s([0-9]+)pcs.pdf/)
  next if count.nil? || count[1].nil? || count[1].to_i <= 0
  count = count[1].to_i
  sheets += count
  forms[f.gsub("tmp/forms/", "tmp/forms/multiple ")] = count
  print count.to_s.rjust(5) + "   "
  puts File.basename(f, ".pdf")
end

puts "-----"
puts sheets.to_s.rjust(5) + " in total"

puts "For reasons unknown the -# switch does not work with lpr."
puts "Didn't test lp, just copying the PDF pages and printing a large PDF instead."
puts "Multiply PDFs? (Press Enter)"
gets
system("cd \"#{mypath}/../tmp/forms/\" && ../../tools/multiply_pdfs.rb")
puts
puts
puts
puts "If you continue, all forms listed above will be uploaded to:"
puts "\t#{account}@#{server}:~/forms_#{semester}"
puts "Press Enter"
gets

puts "Connecting to server"
system("ssh -fNM -o \"ControlPath=/tmp/print_forms_%r@%h:%p\" #{account}@#{server}")
exit 3 if $?.exitstatus != 0

puts
puts
`#{ssh} 'test -d ~/forms_#{semester}'`
if $?.exitstatus == 0
  puts "Target folder exists, aborting. Remove it manually before attemping again."
  exit 1
end

`#{ssh} 'mkdir -p ~/forms_#{semester}'`
exit 3 if $?.exitstatus != 0

puts
puts
puts "Start the mayhem? (Press Enter)"
gets
puts
puts
puts
forms.each do |k,v|
  system("scp -o \"ControlPath=/tmp/print_forms_%r@%h:%p\" \"#{k}\" #{account}@#{server}:~/forms_#{semester}")
  # -# doesn't work :(
  name = File.expand_path("#{homepath}/forms_#{semester}/#{File.basename(k)}")
  system("#{ssh} 'lpr -Pqpsdup -o sides=two-sided-long-edge  \"#{name}\"'")
  system("#{ssh} 'rm \"#{name}\"'")
end

puts "done"
