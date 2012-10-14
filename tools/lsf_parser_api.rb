#!/usr/bin/ruby

# Getting a 403 error thrown when running the script?
# This helper script will only run properly from whitelisted IPs
# This is not a limitation by the script, but a security measure
# by the LSF service.
# I asked if subdomains could be whitelisted, so this would be IP
# independent, but they were still in testing as of writing.
# Currently the following IP has been whitelisted: 129.206.91.26
# If this ever changes, please contact
#     "Reinhard Schmidt" <reinhard.schmidt@urz.uni-heidelberg.de>
# who is in charge of this LSF service.

require File.dirname(__FILE__) + "/lsf_parser_base"

if ARGV.empty? || ARGV.length != 2
  puts "USAGE: ./lsf_parser_api.rb NAME URL"
  puts "The URL can be obtained by copying the link for one of the"
  puts "faculties listed here:"
  puts LSF.toplevel
  puts
  puts "Ensure that you have selected the right term, otherwise"
  puts "you will get old data."
  puts
  puts "These are the links available at top level:"

  LSF.find_suitable_urls.each do |d|
    puts "#{d[:url].ljust(120)} #{d[:title]}"
  end

  exit
end

name = ARGV[0].gsub(/[^a-z0-9_-]/i, "")
term, rootid = LSF.set_term_and_root(ARGV[1])
if term.nil? || rootid.nil? || term == 0 || rootid == 0 || name.nil? || name.empty?
  warn "Couldn't extract term and root id. Please fix the script."
  exit 1
end

data = LSF.get_tree(rootid)
data.freeze

LSF.get_file("lsf_parser_#{name}_kummerkasten.yaml", true).puts LSF.print_yaml_kummerkasten(data, "#{name}")
LSF.get_file("lsf_parser_#{name}_sws.txt", true).puts LSF.print_sws_sheet(data)

render_tex(LSF.print_final_tex(data), "lsf_parser_#{name}_final.pdf", true, true)
render_tex(LSF.print_pre_tex(data), "lsf_parser_#{name}_pre.pdf", true, true)
