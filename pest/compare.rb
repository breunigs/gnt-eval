#!/usr/bin/ruby1.9

# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: COMPARE
#
# Compares two directories of YAML files against each other and compares
# each value. This allows checking for errors easily.
#
# Usage: compare.rb   working_dir   compare_against_dir   [fix]
#
# Working Dir: Path to the files that need to be checked
#
# Compare Dir: Path to the files that are absolutely correct
#
# Fix: Specifiy if you want to open the FIX component for each
# difference. Goto the next difference by closing the FIX component

require 'helper.array.rb'
require 'yaml'

workdir = ARGV.shift
compdir  = ARGV.shift
fix = !ARGV.empty? && ARGV.shift == "fix"

# Ensure all necessary data is there
if !workdir || !compdir || !File.directory?(workdir) || !File.directory?(compdir)
    puts "Usage: compare.rb   working_dir   compare_against_dir   [fix]"
    puts "Working Dir: Path to the files that need to be checked"
    puts "Compare Dir: Path to the files that are absolutely correct"
    puts "Fix: Specifiy if you want to open the FIX component for each difference. Goto the next difference by closing the FIX componet"
    exit
end

# We cannot know that the elements will be in the same order. So this
# small function finds the matching group for a given dbfield
def findGroup(docc, gr)
    docc['page'].allChildren.each { |x| return x if x['dbfield'] == gr }
    nil
end


count = 0 
# Open work folder...
workf = Dir.glob(workdir + "/*.yaml")
# ... and check each file
workf.each do |f|
    # if it is valid
    if File.zero?(f)
       puts File.basename(f) + ":\t Skipping because file is empty!"
       next
    end

    # Check if a comparation file exists
    c = f.gsub(workdir, compdir)
    if !File.exists?(c) || File.zero?(c)
        puts File.basename(c) + ":\t Skipping because compare file does not exist"
        next
    end

    # Load both sheet
    docw = YAML::load(File.new(f))
    docc = YAML::load(File.new(c))

    # Compare each against each
    docw['page'].allChildren.each do |work|
        # Find the same question in the other sheet
        comp = findGroup(docc, work['dbfield'])
        comp['value'] = nil if !comp
        next if work['value'] == comp['value']

        count += 1
        
        # Print differences
        print File.basename(c) + ":\t"
        print work['dbfield'][0..5] + ":\t"
        print work['value'].to_s
        print "\tvs\t"
        print comp['value'].to_s
        puts "\t(work vs comp)"

        # Allow for fix. Next difference by closing the FIX app.
        if fix
            system("ruby fix.rb comp/"+File.basename(f)+" " + work['dbfield'] +" > nul")
            # If the fix app didn't quit properly it probably was killed.
            # So we exit as well because the user wanted to cancel this.
            exit if $? != 0
        end
    end
end

puts "\nFound " + count.to_s + " differences"
