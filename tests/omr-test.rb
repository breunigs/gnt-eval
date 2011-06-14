#!/usr/bin/env ruby

require 'pp'
require 'rubygems'
require 'yaml'
require 'dbi'
require '../lib/FunkyDBBits.rb'
require '../lib/AbstractForm.rb'
require '../pest/helper.AbstractFormExtended.rb'


$tests = []
$failed_tests = []

cdir = File.dirname(__FILE__)
Dir.chdir(cdir) do
  # delete old result files
  `find . -mindepth 3 -regex ".*[0-9]\.yaml" -delete`
  `find . -mindepth 3 -name "*comment.jpg" -delete`

  # check that OMR works
  (0..2).each do |i|
    $tests << "omr2.rb for test_#{i}"
    system("cd .. && ./pest/omr2.rb -c 2 -t -d -o -s tests/test-images/test_#{i}.yaml -p tests/test-images/test_#{i}")
    $failed_tests << $tests.last if $?.exitstatus != 0
  end

  # comapre the newly generated results to the stored reference files
  Dir.glob("./test-images/test_*/*_reference.yaml").each do |cmp|
    ref = YAML::load(File.read(cmp))
    new = YAML::load(File.read(cmp.gsub("_reference", "")))

    ref.questions.each do |rquest|
      nquest = new.questions.find { |x| x.qtext == rquest.qtext }
      rquest.boxes.each do |rbox|
	nbox = nquest.boxes.find { |x| x.choice == rbox.choice }
	$tests << "#{cmp}: quest #{rquest.db_column} box #{rbox.choice} checked: #{rbox.is_checked?}(ref) vs #{nbox.is_checked?} (now)"
	$failed_tests << $tests.last if nbox.is_checked? != rbox.is_checked?

      $tests << "#{cmp}: quest #{rquest.db_column} box #{rbox.choice} critical: #{rbox.is_fill_critical?}(ref) vs #{nbox.is_fill_critical?} (now)"
	$failed_tests << $tests.last if nbox.is_fill_critical? != rbox.is_fill_critical?
      end
    end
  end

  #~ $tests << "omr2.rb for test_0 with multicore and debug output"
  #~ system("cd .. && ./pest/omr2.rb -d -c 2 -o -t -s tests/test-images/test_0.yaml -p tests/test-images/test_0")
  #~ $failed_tests << $tests.last if $?.exitstatus != 0
end




puts
puts
puts
puts
puts
puts "Test summary:"
puts "Ran #{$tests.length} tests of which #{$failed_tests.length} failed."
puts
puts "Failed tests:"
$failed_tests.each { |t| puts "* #{t}" }
