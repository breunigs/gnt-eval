#!/usr/bin/ruby

require 'csv'
require 'pp'
require 'date'
require 'rubygems'
require 'inline' # gem is "RubyInline" and NOT "inline"
require 'time'
require 'yaml'

# CONFIG ###############################################################
$separator = ","
$filename  = Date.today.strftime + " Tutoren Mathe.txt"
$skipMes   = ["mintmachen", "robotik labor", "www-auftrag", "dekanat", "bibliothek", "kurs"]
########################################################################

# Adds terminal control characters to make the given text appear bold
def bold(text)
	"\e[1m#{text}\e[0m"
end


# string distance ######################################################
# http://gist.github.com/147023
class DamerauLevenshtein
  def distance(str1, str2, block_size=2, max_distance=10)
    res = distance_utf(str1.unpack("U*"), str2.unpack("U*"), block_size, max_distance)
    (res > max_distance) ? nil : res
  end

  inline do |builder|
    builder.c "
    static VALUE distance_utf(VALUE _s, VALUE _t, int block_size, int max_distance){
      int min, i,j, sl, tl, cost, *d, distance, del, ins, subs, transp, block, current_distance;

      int stop_execution = 0;

      VALUE *sv = RARRAY_PTR(_s);
      VALUE *tv = RARRAY_PTR(_t);

      sl = RARRAY_LEN(_s);
      tl = RARRAY_LEN(_t);

      int s[sl];
      int t[tl];


      for (i=0; i < sl; i++) s[i] = NUM2INT(sv[i]);
      for (i=0; i < tl; i++) t[i] = NUM2INT(tv[i]);

      sl++;
      tl++;

      //one-dimentional representation of 2 dimentional array len(s)+1 * len(t)+1
      d = malloc((sizeof(int))*(sl)*(tl));
      //populate 'horisonal' row
      for(i = 0; i < sl; i++){
        d[i] = i;
      }
      //populate 'vertical' row starting from the 2nd position (first one is filled already)
      for(i = 1; i < tl; i++){
        d[i*sl] = i;
      }

      //fill up array with scores
      for(i = 1; i<sl; i++){
        if (stop_execution == 1) break;
        current_distance = 10000;
        for(j = 1; j<tl; j++){

          block = block_size < i ? block_size : i;
          if (j < block) block = j;

          cost = 1;
          if(s[i-1] == t[j-1]) cost = 0;

          del = d[j*sl + i - 1] + 1;
          ins = d[(j-1)*sl + i] + 1;
          subs = d[(j-1)*sl + i - 1] + cost;

          min = del;
          if (ins < min) min = ins;
          if (subs < min) min = subs;

          if(block > 1 && i > 1 && j > 1 && s[i-1] == t[j-2] && s[i-2] == t[j-1]){
            transp = d[(j-2)*sl + i - 2] + cost;
            if(transp < min) min = transp;
          }

          if (current_distance > d[j*sl+i]) current_distance = d[j*sl+i];
          d[j*sl+i]=min;
        }
        if (current_distance > max_distance) {
          stop_execution = 1;
        }
      }
      distance=d[sl * tl - 1];
      if (stop_execution == 1) distance = current_distance;

      free(d);
      return INT2NUM(distance);
    }
   "
  end
end

$dl=DamerauLevenshtein.new


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
    dis << $dl.distance(k, name)
    dis << $dl.distance(name, k)
    dis = dis.compact.sort[0]
    next if dis.nil?

    ratio = (((dis-name.length).abs.to_f / name.length.to_f)* 10**2).round.to_f/10**2

    next if ratio < 0.5

    candidates[k] = "#{dis.to_s.rjust(2)} (#{ratio.to_s.rjust(4)} similar)"
  end

  return name if candidates.empty?

  t = "The following lectures appear to be similar to \"#{bold(name)}\":"
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
    dis << $dl.distance(new, name)
    dis << $dl.distance(name, new)
    dis = dis.compact.sort[0]
    next if dis.nil?

    ratio = (((dis-name.length).abs.to_f / name.length.to_f)* 10**2).round.to_f/10**2

    next if ratio < 0.5

    candidates[name] = "#{dis.to_s.rjust(2)} (#{ratio.to_s.rjust(4)} similar)"
  end

  return new if candidates.empty?

  t = "The following tutors appear to be similar to \"#{bold(new)}\":"
  askUser(t, new, candidates, false)
end

# Asks the user if a given name is similar to a given list of candidates
# text:       the question (should name the 'new' item in question)
# default:    the 'new' item itself (used if the user says it's not similar)
# candidates: the candidates similar to the 'default'
# save_similar: if the similar information should be saved
def askUser(text, default, candidates, save_similar)
  puts text
  puts "-"*(text.length - bold("").length)
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
