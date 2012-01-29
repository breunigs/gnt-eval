#!/usr/bin/env ruby

require File.dirname(__FILE__) + "/../lib/RandomUtils.rb"
require File.dirname(__FILE__) + "/../lib/seee_config.rb"

interactive = true

# Define which tray contains which type of sheet
TRAY_NORMAL="1Tray,2Tray,3Tray"
TRAY_BANNER="4Tray"

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

# Print a warning after this many sheets in order to allow easy refill
# of printer paper without the printer accidentally taking it from the
# banner slot.
SHEET_WARNING=1000


GNT_ROOT=File.expand_path(File.join(File.dirname(__FILE__), "..")) unless defined?(GNT_ROOT)
# change into tmp directory
Dir.chdir(Seee::Config.file_paths[:cache_tmp_dir])

sheets = 0
forms = {}

# look in default location, if no paths are given via CMD line.
if ARGV.nil? || ARGV.empty?
  poss = Dir.glob("#{GNT_ROOT}/../forms/*pcs.pdf")
else
  poss = ARGV
  if poss.include?("--non-interactive")
    interactive = false
    poss.delete("--non-interactive")
  end
end


if interactive
  puts
  puts "Please run rm -r tmp/forms && rake forms:generate && rake misc:howtos"
  puts "before running this script. Otherwise forms might be missing"
  puts "or outdated ones will be printed."
  puts
  puts "Type 'yes' to continue."
  input = gets.strip.downcase
  exit 1 unless input == "yes"
  puts
  puts
  puts
end

# now check the given files if they are suitable
poss.each do |f|
  next unless File.exist?(f)
  next if File.basename(f).start_with?(" multiple")
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

puts "Normal Paper: #{TRAY_NORMAL}"
puts "Banner Pages: #{TRAY_BANNER}"
puts "Check the trays are filled accordingly. Going to print large"
puts "sheets first. Will print a warning every #{SHEET_WARNING} sheets; you should"
puts "wait submitting more jobs until the printer is finished and paper"
puts "has been refilled."
puts "Waiting once in a while also allows to give a time estimate."

# create empty file to print banner pages with. No need to waste paper…
system("echo '   ' > bannerpage.txt")

bin = BIN_SMALL
warningcounter = 0
totalcounter = 0
start_time = Time.now

forms.sort { |a,b| b[1][:count] <=> a[1][:count] }.each do |file, data|
  count = data[:count]
  howtos = ([data[:lang]] + DEFAULT_HOWTOS).uniq

  puts
  puts
  puts
  puts file.gsub(/^tmp\/forms\//, "")
  puts "About to print #{count} sheets for that. Continue? [Y/n]"

  # Ask if we want to continue. Note how long it took to take that
  # decision and assume for longer intervals that we waited for the
  # printer to finish. Doesn’t handle answer “no”, simply won’t print
  # estimate then.
  decision_time = Time.now
  if interactive
    input = gets.strip.downcase
    unless input.empty? || input == "y"
      puts "Skipping"
      puts
      next
    end
  end

  # cycle bins
  if bin == BIN_SMALL || count > 150
    bin = BIN_LARGE
  else
    bin = BIN_SMALL
  end

  # issue print commands / submit to queue
  print =  "lpr -##{count} -o OutputBin=#{bin} -o InputSlot=#{TRAY_NORMAL} #{LPR_OPTIONS} \"#{file}\""
  banner = "lpr -#1        -o OutputBin=#{bin} -o InputSlot=#{TRAY_BANNER} #{LPR_OPTIONS} \"#{Dir.pwd}/bannerpage.txt\""
  howtos.map! { |h| "lpr -#1 -o OutputBin=#{bin} -o InputSlot=#{TRAY_NORMAL} #{LPR_OPTIONS} \"#{Dir.pwd}/howtos/howto_#{h}.pdf\"" }
  howtos.each { |h| system(h) }
  system(print)
  system(banner)
  puts "The sheets will be put in the #{BIN_DESC[bin].bold}"
  puts

  # give time estimate if we can assume we waited for the printer. Also
  # don’t break the program if the estimate calculation goes awry.
  begin
    if (Time.now-decision_time) > 30
      left = sheets - totalcounter
      time_taken = Time.now-start_time
      time_per_sheet = time_taken / totalcounter.to_f
      ttg = Time.at(left*time_per_sheet).gmtime.strftime('%kh %Mm')
      puts
      puts
      puts "You took longer than 30s to decide if to continue. Assuming"
      puts "this means you waited for the printer. Here’s an estimate:"
      puts "#{totalcounter} sheets took #{time_taken}s to print."
      puts "That’s #{time_per_sheet} per sheet."
      puts "#{left} to go, so about #{ttg.bold} to go."
      puts
      puts
    end
  rescue; end
  totalcounter += count # not counting howtos here

  puts "#{totalcounter} of #{sheets} have been queued/printed."

  # print warning, if many sheets have been queued
  warningcounter += howtos.size + count
  if warningcounter > SHEET_WARNING
    puts
    puts "="*35
    puts "#{SHEET_WARNING} sheets warning (#{warningcounter} in queue)"
    puts "="*35
    warningcounter = 0
  end
end

puts "done"
