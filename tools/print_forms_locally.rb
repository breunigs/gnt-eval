#!/usr/bin/env ruby

mypath=File.dirname(__FILE__)
# change into seee root directory
Dir.chdir(File.join(mypath, ".."))

RAILS_ROOT = 'web'
class Rails
  def self.root
    RAILS_ROOT
  end
end
require 'web/app/lib/ext_requirements.rb'

semester = Semester.find(:all).find { |s| s.now? }.title.gsub(/\s+/, "_").scan(/[-_a-z0-9]+/i).join

if semester.nil?
  puts "Could not detect current semester. Exiting."
  exit 1
end

sheets = 0
forms = {}

puts "The following forms will be printed:"
Dir.glob("tmp/forms/*pcs.pdf") do |f|
  # skip forms that include their copies in the file.
  next if File.basename(f).start_with?("multiple")
  next unless f.match(/quantum/i)
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
puts "Will take normal paper from Tray 1."
puts "Will take separation pages from Tray 3."
puts "Please ensure the trays are filled beforehand."

system("echo '   ' > tmp/bannerpage.txt")

puts
puts
puts

# Define which bins are available
BIN_LARGE="FinKINGShift"  # on bottom
BIN_SMALL="FinEUPHBUpper" # on top
BIN_DESC={ BIN_LARGE => "bin on bottom", BIN_SMALL => "bin on top" }

# start with one
bin=BIN_LARGE

forms.each do |file,count|
  puts file.gsub(/^tmp\/forms\//, "")
  puts "About to print #{count} sheets for that. Continue? [Y/n]"
  input = gets.strip.downcase
  if input.empty? || input == "y"
    if bin == BIN_SMALL || count > 70
      bin = BIN_LARGE
    else
      bin = BIN_SMALL
    end

    print = "lpr -##{count} -o sides=two-sided-long-edge -o OutputBin=#{bin} -o InputSlot=1Tray -o PageSize=A4 \"#{Dir.pwd}/#{file}\""
    banner = "lpr -#1 -o OutputBin=#{bin} -o InputSlot=3Tray #{Dir.pwd}/tmp/bannerpage.txt"
    system(print)
    system(banner)
    puts "The sheets will be put in the #{BIN_DESC[bin]}"
    puts
    puts
  else
    puts "Skipping"
  end
  puts
end

puts "done"
