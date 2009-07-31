#!/usr/bin/ruby1.9

# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: YAML2SQL
#
# Finds all suitable YAML files in the given working directory and
# outputs a nice SQL file that may be easily imported into any database.
#
# Usage: xml2sql.rb   working_dir   output.sql   [overwrite]"

require 'yaml'
require 'helper.array.rb'
require 'pp'

workdir = ARGV.shift
output  = ARGV.shift
overwrite = (ARGV.shift == "overwrite")

if !workdir || !output || !File.directory?(workdir) 
    puts "Usage: xml2sql.rb   working_dir   output.sql   [overwrite]"
    exit
end

# Create directories where to save the SQL output
begin
    File.mkdirs(File.dirname(output))
rescue; end

if File.exists?(output) && !overwrite && !File.zero?(output)
    puts "Output file exists and overwrite is not specified, exiting"
    exit
end

puts "Starting export"

fout = File.open(output, "w")

files = Dir.glob(workdir + "/*.yaml")
i = 0
addkeys = true
allvals = []

files.each do |f|
    if File.zero?(f)
        puts "Ignoring empty file: " + f
        next
    end
    i+=1
    # Writes the SQL data and simply assumes there are no ` in dbfields,
    # values or the filenames. Otherwise, a kitten will die.
    @keys = [] if addkeys
    vals = []
    doc = YAML::load(File.new(f))
    @dbtable = doc['dbtable'] if addkeys

    # Write some meta information that is not stored in the YAML file
    # itself
    time = File.atime(f)
    @keys << "filename" if addkeys
    vals << File.basename(f)

    @keys << "datum" if addkeys
    vals << time.strftime("%Y-%m-%d")

    @keys << "uhrzeit" if addkeys
    vals << time.strftime("%I:%M:%S")

    # Write the actual values
    begin
        doc['page'].allChildren.each do |g|
            @keys << g['dbfield'] if addkeys
            vals << g['value']
        end
    rescue
        puts "FAILED PARSING SHEET!"
        puts "FILENAME: " + f
        pp doc
    end

    allvals << "('" + vals.join("', '") + "')"
    addkeys = false
end

puts "Stichting and writing..."
# Put it all together
sql = "INSERT INTO "
sql << "`" + @dbtable + "`"
sql << " (`"
sql << @keys.join("`, `")
sql << "`) VALUES \n"
sql << allvals.join(", \n")
sql << ";"

# Write it to file
fout.puts sql
fout.close

puts "All data has been written to " + output
