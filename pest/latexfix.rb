#!/usr/bin/env ruby
# encoding: utf-8

# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: LaTeX Indentionfixer
#
# It's impossible or at least very hard to tell LaTeX to correctly
# indent the YAML file with spaces. Therefore, the indentation is done
# using leading 'u's instead. This script replaces those with normal
# spaces so it can be parsed as YAML file.
#
# The same can be said about YAML comments which are identified by a
# leading '#'. Those are expressed by a capital 'U'.

if ARGV.empty?
    puts "Usage: ./latexfix.rb fixme1.yaml [fixme2.yaml, ...]"
    exit
end

ARGV.each do |file|
    f = File.open(file, "r");
    newfile = []
    f.each do |l|
        newfile << l.gsub(/^uuu\s/, "  "*3)        \
                    .gsub(/^uu\s/,  "  "*2)        \
                    .gsub(/^u\s/,   "  "*1)        \
                    .gsub(/^uuu-/, ("  "*3) + "-") \
                    .gsub(/^uu-/,  ("  "*2) + "-") \
                    .gsub(/^u-/,   ("  "*1) + "-") \
                    .gsub(/^U/, "#")
    end
    f.close
    f = File.open(file.gsub(/posout$/, "yaml"), "w+")
    f.write newfile
    f.close
end
