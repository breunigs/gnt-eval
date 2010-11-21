#!/usr/bin/env ruby

# Usage: multiply_pdfs.rb path/to/some/pdfs
# The PDFs must end in "1234pcs.pdf" where
# the number defines how many copies should
# be included in the new PDF file.

err = []

Dir.chdir(ARGV[0]) if ARGV[0]

files = Dir.glob("*[0-9]pcs.pdf")

files.each do |x|
	match = x.match(/^(.*?)([0-9]+)pcs.pdf$/)
	num = match[2].to_i
	nam = match[1]
	if num <= 1
		puts "Invalid amount (#{num}) specified. Skipping #{x}."
		err << x
		next
	end

	if File.exists?("multiple #{x}")
		puts "A multiplied version of \"#{x}\" already exists. Skipping."
		next
	end

	puts "Creating #{num} copies for #{x}…"

	# Will likely break for non-latin1 characters, although
	# it should be fixed. Ignore that for the moment.
	`pdftk A="#{x}" cat #{"A "*num} output "multiple #{x}"`
	err << x if $?.exitstatus != 0
end

puts
puts "Done (processed #{files.count} file(s) with #{err.count} error(s))"
puts
puts "The following documents could no be processed:" unless err.empty?
puts err.join("\n")
