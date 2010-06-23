#!/usr/bin/ruby

require 'csv'
require 'pp'
require 'date'

if ARGV[0].nil? || ARGV[0].empty?
    puts "Please specify hiwi.csv to parse"
    exit
end

unless File.exists? ARGV[0]
    puts "Given input file does not exist."
    exit
end

vl = Hash.new
tutoren = 0

CSV.open(ARGV[0], 'r') do |row|
    next if row[0].nil? # Vorlesung
    next if row[3].nil? || row[3].strip.empty? # Spalte 'G' für genehmigt

    t = row[0].strip.downcase
    next if t == "robotik labor" || t == "www-auftrag" || t == "dekanat" || t == "bibliothek" || t == "kurs"
    # 8: Tutor Vorname
    # 7: Tutor Nachname
    vl[row[0]] = Array.new if vl[row[0]].nil?
    vl[row[0]] << "#{row[8]} #{row[7]}".strip
    tutoren += 1
end

filename = Date.today.strftime + " Tutoren Mathe.txt"
File.open(filename, 'w') do |f|
    vl.each do |vl,tuts|
        f.puts "#{vl}:"
        f.puts tuts.join(",")
        f.puts
    end
end

puts "Statistik:"
puts "#{vl.length} Vorlesungen"
puts "#{tutoren} Tutoren"
