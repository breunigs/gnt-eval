#!/usr/bin/ruby1.8

# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: LaTeX Indentionfixer
#
# It's impossible or at least very hard to tell LaTeX to correctly
# indent the YAML file with spaces. Therefore, the indentation is done
# using leading 'u's instead. This script replaces those with normal
# spaces so it can be parsed as YAML file.

if ARGV.empty?
    puts "Usage: ./latexfix.rb fixme1.yaml [fixme2.yaml, ...]"
    exit
end

ARGV.each do |file|
    f = File.open(file, "r");
    newfile = []
    f.each do |l|
        newfile << l.gsub(/^uuu\s/, "  " * 3) \
                    .gsub(/^uu\s/, "  " * 2)  \
                    .gsub(/^u\s/, "  ")       \
                    .gsub(/^uuu-/, ("  " * 3) + "-")  \
                    .gsub(/^uu-/,  ("  " * 2) + "-")       \
                    .gsub(/^u-/, ("  ")  + "-")
    end
    f.close
    f = File.open(file.gsub(/posout$/, "yaml"), "w+")
    f.write newfile
    f.close
end

