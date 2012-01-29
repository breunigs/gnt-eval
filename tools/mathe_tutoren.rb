#!/usr/bin/ruby

require 'csv'
require 'pp'
require 'date'
require 'rubygems'
require 'text'
require 'time'
require 'yaml'
require "#{File.dirname(__FILE__)}/../lib/RandomUtils.rb"

# CONFIG ###############################################################
$separator = ","
$filename  = Date.today.strftime + " Tutoren Mathe.txt"
$skipMes   = ["mintmachen", "robotik labor", "www-auftrag", "dekanat", "bibliothek", "kurs"]
########################################################################


# data storage #########################################################
class Lecture
  attr_accessor :lecturer, :student_count, :tutors

  def initialize
    @lecturer = ""
    @student_count = 0
    @tutors = []
  end
end

$lectures = Hash.new
$savedSimilar = Hash.new
$falseFriends = Hash.new

$savedSimilar["Höhere Analysis"] = "Analysis 3"
$savedSimilar["Algebra I"] = "Algebra 1"
$savedSimilar["Analysis I"] = "Analysis 1"
$savedSimilar["Analysis II"] = "Analysis 2"
$savedSimilar["Einführung in die Numerik (\"Numerik 0\")"] = "Numerik 0"
$savedSimilar["Einführung in die Numerik"] = "Numerik 0"
$savedSimilar["Einführung in die Wahrscheinlichkeitstheorie"] = "Einführung in die Wahrscheinlichkeitstheorie und Statistik"


$falseFriends["Lineare Algebra 1"] = ["Algebra 1", "Liealgebren"]
$falseFriends["Liealgebren"] = ["Lineare Algebra 1", "Analysis 1", "Analysis 3"]
$falseFriends["Algebra 1"] = ["Analysis 1", "Lineare Algebra 1", "Liealgebren"]
$falseFriends["Analysis 1"] = ["Analysis 3", "Algebra 1", "Liealgebren"]
$falseFriends["Analysis 3"] = ["Analysis 1", "Liealgebren"]


# find similar #########################################################

# Accepts a name and tries to find a similar one in existing $lectures.
# May prompt the user. Returns either name or a similar one.
def findLecture(name)
  return $savedSimilar[name] unless $savedSimilar[name].nil?

  # find possible candidates
  candidates = Hash.new
  $lectures.each_key do |k|
    return name if k == name

    next if !$falseFriends[name].nil? && $falseFriends[name].include?(k)

    dis = []
    dis << Text::Levenshtein.distance(k, name)
    dis << Text::Levenshtein.distance(name, k)
    dis = dis.compact.sort[0]
    next if dis.nil?

    ratio = (((dis-name.length).abs.to_f / name.length.to_f)* 10**2).round.to_f/10**2

    next if ratio < 0.5

    candidates[k] = "#{dis.to_s.rjust(2)} (#{ratio.to_s.rjust(4)} similar)"
  end

  return name if candidates.empty?

  t = "The following lectures appear to be similar to \"#{name.bold}\":"
  askUser(t, name, candidates, true)
end

# Looks up if a similar tutor already exists (list = existing tutors,
# new = new tutor)
def findTutor(list, new)
  return new if list.empty?
  if new.is_a? Array
    (0..(new.length-1)).each do |i|
      new[i] = findTutor(list, new[i])
    end
    return new
  end

  # find possible candidates
  candidates = Hash.new
  list.each do |name|
    return new if new == name

    dis = []
    dis << Text::Levenshtein.distance(new, name)
    dis << Text::Levenshtein.distance(name, new)
    dis = dis.compact.sort[0]
    next if dis.nil?

    ratio = (((dis-name.length).abs.to_f / name.length.to_f)* 10**2).round.to_f/10**2

    next if ratio < 0.5

    candidates[name] = "#{dis.to_s.rjust(2)} (#{ratio.to_s.rjust(4)} similar)"
  end

  return new if candidates.empty?

  t = "The following tutors appear to be similar to \"#{new.bold}\":"
  askUser(t, new, candidates, false)
end

# Asks the user if a given name is similar to a given list of candidates
# text:       the question (should name the 'new' item in question)
# default:    the 'new' item itself (used if the user says it's not similar)
# candidates: the candidates similar to the 'default'
# save_similar: if the similar information should be saved
def askUser(text, default, candidates, save_similar)
  puts text
  puts "-"*(text.length - "".bold.length)
  csort = candidates.to_a.sort { |x,y| x[1] <=> y[1] }
  csort.each_with_index do |item,i|
    puts "##{(i+1).to_s.rjust(2)}  ⎸ Δ: #{item[1]}  ⎸ #{item[0]}"
  end
  puts "Hit enter if there's no match"
  while true
    puts
    puts "Your choice:"
    a = STDIN.gets.strip
    return default if a == "" || a.empty?
    a = a.to_i
    next if a <= 0 || a > csort.length
    $savedSimilar[default] = csort[a-1][0] if save_similar
    puts
    return csort[a-1][0]
  end
end

# file parsers #########################################################

# Tries to parse the given CSV sheet. Stores data directly in $lectures.
def parseCSV(x)
  puts "Processing CSV #{x}"
  CSV.open(x, 'r') do |row|
    # 8: Tutor 1st name
    # 7: Tutor last name
    tut = "#{row[8]} #{row[7]}".gsub(/\s+/, " ").strip

    next if row[0].nil? # lecture
    next if row[3].nil? || row[3].strip.empty? # column 'G' for 'genehmigt'

    t = row[0].strip.downcase
    next if $skipMes.include?(t)

    next if tut == "NN" || tut == "N.N." || tut == "NN."

    row[0] = "Einführung in die #{row[0].gsub(/ Einführung$/, "")}" if row[0].match(/ Einführung$/)

    # try to find a similar named lecture
    name = findLecture(row[0].strip)

    $lectures[name] ||= Lecture.new
    $lectures[name].tutors << findTutor($lectures[name].tutors, tut)
    $lectures[name].lecturer = row[11].strip
  end
end

# Tries to parse the given YAML sheet. Stores data directly in $lectures
def parseYAML(x)
  puts "Processing YAML #{x}"
  lecture=""
  begin
    YAML::load(File.read(x)).each do |l|
      # try to find a similar lecture
      lecture = findLecture(l["name"])
      tuts = l["tutors"].collect { |t| t.gsub(/\s+/, " ").strip }

      $lectures[lecture] ||= Lecture.new
      $lectures[lecture].tutors += findTutor($lectures[lecture].tutors, tuts)
      $lectures[lecture].student_count = l["student_count"]
      $lectures[lecture].lecturer = l["lecturer"]
    end
  rescue => e
    puts "#{x} does not appear to be a 'good' YML file for the task at hand. Skipping."
    puts "Lecture was: #{lecture}"
    puts "Error:"
    pp e
    return
  end
end


# Check if the input values are sane ###################################
if ARGV[0].nil? || ARGV[0].empty?
    puts "Please specify hiwi.csv or lectures.yml (or both) to parse"
    exit 1
end

ARGV.each do |x|
  next if File.exists? x
  puts "Input file #{x} does not exist."
  exit 1
end


# actual processing ####################################################

# parse each specified file and try to merge
ARGV.each do |x|
  case x.reverse[0..3].reverse.downcase
    when ".csv" then
      parseCSV(x)
    when ".yml", "yaml" then
      parseYAML(x)
    when ".xls", "xlsx" then
      puts "XLS-format is not supported. Please convert #{x} to CSV first."
    else
      puts "Unknown format: #{x}"
  end
end


File.open($filename, 'w') do |f|
  $savedSimilar.each_pair do |k,v|
    f.puts "Replaced: #{k} → #{v}"
  end
  f.puts
  f.puts
  f.puts

  $lectures.each do |vl,x|
    next if x.tutors.empty? && x.student_count == 0
    f.puts '#################'
    f.puts vl
    f.puts x.lecturer
    f.puts "Teilnehmer: #{x.student_count}"
    f.puts '#################'
    f.puts x.tutors.uniq.sort.join($separator)
    f.puts ''
    f.puts ''
    f.puts ''
  end
end


puts
puts
puts
puts "Done. Have a look at #{$filename}"
