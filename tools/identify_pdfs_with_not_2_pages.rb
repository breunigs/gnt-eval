#!/usr/bin/env ruby

ARGV.each do |filename|
  command = "pdfinfo \"#{filename}\" | grep Pages: | awk '{print $2}'" 
  pages = `#{command}`.to_i
  puts filename unless pages == 2
end
