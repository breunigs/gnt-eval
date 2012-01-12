#!/usr/bin/env ruby

# Define which tray contains which type of sheet
TRAY_NORMAL="1Tray"
TRAY_BANNER="3Tray"

# Define which bins are available
BIN_LARGE="FinKINGShift"  # on bottom
BIN_SMALL="FinEUPHBUpper" # on top
BIN_DESC={ BIN_LARGE => "bin on bottom", BIN_SMALL => "bin on top" }

# Other print options which are handed to each lpr run
LPR_OPTIONS="-o sides=two-sided-long-edge -o PageSize=A4"

# Define which how to languages to print in addition to the one of the
# sheet at hand. E.g., if this is set to “en”, an “en” sheet will yield
# one English howto. A “de” sheet will yield a German and English howto.
DEFAULT_HOWTOS=["de"]


mypath=File.dirname(__FILE__)
# change into seee root directory
Dir.chdir(File.join(mypath, ".."))

sheets = 0
forms = {}

puts
puts "Please run rm -r tmp/forms && rake pdf:forms && rake pdf:howto"
puts "before running this script. Otherwise forms might be missing"
puts "or outdated ones will be printed."
puts

Dir.glob("tmp/forms/*pcs.pdf") do |f|
  # skip forms that include their copies in the file.
  next if File.basename(f).start_with?("multiple")
  data = f.match(/.*\s-\s([a-z]+)\s-\s.*\s([0-9]+)pcs.pdf/)
  next if data.nil? || data[1].nil? || data[2].nil? || data[2].to_i <= 0
  count = data[2].to_i
  sheets += count
  forms[f] = { :count => count, :lang => data[1] }
end

if forms.empty?
  puts "No forms found."
  exit
end

puts "#{sheets} in total, plus how tos and banner pages."
puts "Normal Paper: #{TRAY_NORMAL}"
puts "Banner Pages: #{TRAY_BANNER}"
puts "Check the trays are filled accordingly."

# create empty file to print banner pages with. No need to waste paper…
system("echo '   ' > tmp/bannerpage.txt")



forms.each do |file, data|
  count = data[:count]
  howtos = ([data[:lang]] + DEFAULT_HOWTOS).uniq

  puts
  puts
  puts
  puts file.gsub(/^tmp\/forms\//, "")
  puts "About to print #{count} sheets for that. Continue? [Y/n]"

  # do we want to print this sheet?
  input = gets.strip.downcase
  unless input.empty? || input == "y"
    puts "Skipping"
    puts
    next
  end

  # cycle bins
  if !defined?(bin) || bin == BIN_SMALL || count > 70
    bin = BIN_LARGE
  else
    bin = BIN_SMALL
  end



  # actually print
  print =  "lpr -##{count} -o OutputBin=#{bin} -o InputSlot=#{TRAY_NORMAL} #{LPR_OPTIONS} \"#{Dir.pwd}/#{file}\""
  banner = "lpr -#1        -o OutputBin=#{bin} -o InputSlot=#{TRAY_BANNER} #{LPR_OPTIONS} \"#{Dir.pwd}/tmp/bannerpage.txt\""
  howtos.map! { |h| "lpr -#1 -o OutputBin=#{bin} -o InputSlot=#{TRAY_NORMAL} #{LPR_OPTIONS} \"#{Dir.pwd}/tmp/howto_#{h}.pdf\"" }
  system(print)
  howtos.each { |h| system(h) }
  system(banner)
  puts "The sheets will be put in the #{BIN_DESC[bin]}"
  puts
end

puts "done"
