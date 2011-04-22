#!/usr/bin/env ruby

account = "re9"
server = "kde05.urz.uni-heidelberg.de"
ssh = "ssh -o \"ControlPath=/tmp/print_forms_%r@%h:%p\" #{account}@#{server}"

RAILS_ROOT = File.dirname(__FILE__) + '/../web'
class Rails
  def self.root
    RAILS_ROOT
  end
end
require File.dirname(__FILE__) + '/../web/app/lib/ext_requirements.rb'

semester = Semester.find(:all).find { |s| s.now? }.title.gsub(/\s+/, "_").scan(/[-_a-z0-9]+/i).join

if semester.nil?
  puts "Could not detect current semester. Exiting."
  exit 1
end

sheets = 0
forms = {}

puts "The following forms will be printed:"
Dir.glob(File.dirname(__FILE__) + "/../tmp/forms/*pcs.pdf") do |f|
  count = f.match(/.*\s([0-9]+)pcs.pdf/)
  next if count.nil? || count[1].nil? || count[1].to_i <= 0
  count = count[1].to_i
  sheets += count
  forms[f] = count
  print count.to_s.rjust(5) + "   "
  puts File.basename(f, ".pdf")
end

puts "-----"
puts sheets.to_s.rjust(5) + " in total"

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

puts "Copying files to server"
`scp -o "ControlPath=/tmp/print_forms_%r@%h:%p" "#{forms.keys.join('" "')}" #{account}@#{server}:~/forms_#{semester}`
exit 3 if $?.exitstatus != 0

puts
puts
forms.each do |k,v|
  name = "~/forms_#{semester}/#{File.basename(k)}"
  system("echo 'SHALL I DO THIS: llllpr -Pqpsdup -o sides=two-sided-long-edge -# #{v} \"#{name}\"'")
  gets
  puts "skiiiping real lpr"
  #`#{ssh} 'llllpr -Pqpsdup -o sides=two-sided-long-edge -# #{v} "#{name}"'`
end
