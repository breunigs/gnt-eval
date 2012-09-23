#!/usr/bin/env ruby
# encoding: utf-8

require "yaml"
require File.dirname(__FILE__) + "/../web/app/lib/AbstractForm.rb"


unless File.exist?(ARGV[0]) && File.exist?(ARGV[1])
  warn "Usage: compare-yaml.rb 1.yaml 2.yaml"
  exit 1
end

a = YAML::load(File.read(ARGV[0]))
b = YAML::load(File.read(ARGV[1]))

$fails = 0

def compare(a, b, level = 0, head = "")
  # skip early if possible
  return if a == b

  s = "  " * level
  ident = ""
  begin; ident = a.title; rescue; end
  begin; ident = a.qtext; rescue; end
  begin; ident = a.text; rescue; end

  head += "\n#{"--"*level} #{a.class}: #{ident.to_s[0..80]}"

  (a.instance_variables + b.instance_variables).uniq.each do |iv|
    x = a.instance_variable_get(iv)
    y = b.instance_variable_get(iv)
    next if x == y

    if x.class != y.class
      l = 67 - 2*level
      puts head; head = ""
      puts "#{s} #{iv.to_s.ljust(12)} type differs"
      puts "#{s}   Type A: #{x.class.to_s.ljust(12)} (#{x.to_s[0..l]})"
      puts "#{s}   Type B: #{y.class.to_s.ljust(12)} (#{y.to_s[0..l]})"
      $fails += 1
      next
    end

    if x.is_a?(Array)
      min = [x.size, y.size].min
      if x.size != y.size
        puts head; head = ""
        puts "#{s} #{iv}: #{x.size} vs. #{y.size}"
        puts "#{s} Note: only first #{min} #{iv} are compared"
        $fails += 1
      end
      (0..min-1).each { |i| compare(x[i], y[i], level+1, head) }
    else
      puts head; head = ""
      puts "#{s} #{iv.to_s.ljust(12)} differ"
      puts "#{s}   A: #{x}"
      puts "#{s}   B: #{y}"
      $fails += 1
    end
  end
end

compare(a, b)
puts "Differences: #{$fails}"
