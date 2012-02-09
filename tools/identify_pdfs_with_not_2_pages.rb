#!/usr/bin/env ruby

if ARGV.empty?
  warn "No filenames given."
  exit 1
end

ARGV.each do |filename|
  command = "pdfinfo \"#{filename}\" | grep Pages: | awk '{print $2}'"
  pages = `#{command}`.to_i
  puts filename unless pages == 2
end
