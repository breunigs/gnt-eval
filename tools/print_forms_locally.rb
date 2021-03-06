#!/usr/bin/env ruby
# encoding: utf-8

require File.dirname(__FILE__) + "/../web/config/ext_requirements.rb"

interactive = true
simulate = false
print_howtos = true
overwrite_count = false
given_amount = 0

# Define which tray contains which type of sheet
TRAY_NORMAL="1Tray,2Tray,3Tray"
TRAY_BANNER="4Tray"

# Define which bins are available
BIN_LARGE="FinKINGShift"  # on bottom
BIN_SMALL="FinEUPHBUpper" # on top
BIN_DESC={ BIN_LARGE => "bin on bottom", BIN_SMALL => "bin on top" }

# Other print options which are handed to each lpr run
LPR_OPTIONS="-o sides=two-sided-long-edge -o PageSize=A4 -o Resolution=300dpi"

# If the questionnaires need to be stapled (i.e. more than two pages)
# this determines how:
STAPLE="-o StapleLocation=UpperLeft"

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
  poss = Dir.glob("#{GNT_ROOT}/tmp/forms/*pcs.pdf")
else
  poss = ARGV
  if poss.include?("--non-interactive")
    interactive = false
    poss.delete("--non-interactive")
    puts "Printing non-interactively."
  end

  if poss.include?("--simulate")
    simulate = true
    poss.delete("--simulate")
    puts "Simulating only. LPR is not really called."
  end

  if poss.include?("--no-howtos")
    print_howtos = false
    poss.delete("--no-howtos")
    puts "Not printing howtos."
  end

  poss.reject! do |p|
    next false unless m = p.match(/^--amount=([0-9]+)$/)
    puts "Automatic count detection is deactivated. Will always print #{m[1]} sheets."
    overwrite_count = true
    given_amount = m[1].to_i
    true
  end
end

# only command options have been given, but no files. Use default.
if poss.empty?
  poss = Dir.glob("#{GNT_ROOT}/tmp/forms/*pcs.pdf")
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
  unless File.exist?(f)
    puts "File #{f} not found, skipping"
    next
  end
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

forms_sorted = forms.sort do |a,b|
  if b[1][:count] == a[1][:count]
    a[0] <=> b[0]
  else
    b[1][:count] <=> a[1][:count]
  end
end

forms_sorted.each do |file, data|
  count = overwrite_count ? given_amount : data[:count]
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

  pages = `pdfinfo "#{file}" | grep Pages: | awk '{print $2}'`.to_i
  if pages > 2
    warn "Sheet to print has more than 2 pages. Trying to staple them."
  end


  # cycle bins
  if bin == BIN_SMALL || count > 150 || pages > 2
    bin = BIN_LARGE
  else
    bin = BIN_SMALL
  end

  # issue print commands / submit to queue
  cover_file = File.join(File.dirname(file), "covers", "cover #{File.basename(file)}")
  cover =  "lpr            -o landscape=false -o OutputBin=#{bin} -o InputSlot=#{TRAY_NORMAL} #{LPR_OPTIONS} \"#{cover_file}\""
  print =  "lpr -##{count} -o landscape=false -o OutputBin=#{bin} -o InputSlot=#{TRAY_NORMAL} #{LPR_OPTIONS} #{pages > 2 ? STAPLE : ""} \"#{file}\""
  banner = "lpr -#1        -o landscape=false -o OutputBin=#{bin} -o InputSlot=#{TRAY_BANNER} #{LPR_OPTIONS} \"#{Dir.pwd}/bannerpage.txt\""
  howtos.map! { |h| "lpr -#1 -o landscape=false -o OutputBin=#{bin} -o InputSlot=#{TRAY_NORMAL} #{LPR_OPTIONS} \"#{File.dirname(file)}/../howtos/howto_#{h}.pdf\"" }
  unless simulate
    system(cover) if File.exists?(cover_file)
    howtos.each { |h| system(h) } if print_howtos
    system(print)
    system(banner)
  else
    puts(cover) if File.exists?(cover_file)
    howtos.each { |h| puts(h) } if print_howtos
    puts(print)
    puts(banner)
  end
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
  warningcounter += howtos.size + count*(pages/2.0).ceil
  if warningcounter > SHEET_WARNING
    puts
    puts "="*35
    puts "#{SHEET_WARNING} sheets warning (#{warningcounter} in queue)"
    puts "="*35
    warningcounter = 0
  end
end

puts "done"
