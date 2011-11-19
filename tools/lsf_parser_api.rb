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
    puts TOPLEVEL
    puts
    puts "Ensure that you have selected the right semester, otherwise"
    puts "you will get old data."
    puts
    puts "These are the links available at top level:"

    findSuitableURLs.each do |d|
      puts "#{BASELINK}#{d[0].ljust(30)} #{d[1]}"
    end

    exit
else
    @name = ARGV[0].gsub(/[^a-z0-9_-]/i, "")
    setSemAndRootFromURL(ARGV[1])
    if @semester.nil? || @rootid.nil? || @semester == 0 || @rootid == 0 || @name.nil? || @name.empty?
        puts "Couldn't extract semester and root id. Please fix"
        puts "the script's code".
        exit
    end
end

data = getTree(@rootid)

# do not fix the order of these! printFinalList calls
# listProfs in a way that will destruct the data sets.
# Or you /could/ fix either of these functions.
getFile("lsf_parser_#{@name}_pre.html", true).puts printPreList(data)
getFile("lsf_parser_#{@name}_kummerkasten.yaml", true).puts printYamlKummerKasten(data, "#{@name}")
getFile("lsf_parser_#{@name}_final.html", true).puts printFinalList(data)
getFile("lsf_parser_#{@name}_sws.txt", true).puts printSWSSheet(data)



puts "Cache hits: #{$cache_hits}"
