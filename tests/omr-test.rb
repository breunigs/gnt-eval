#!/usr/bin/env ruby

require 'pp'
require 'rubygems'
require 'yaml'
require 'dbi'
require '../web/app/lib/AbstractForm.rb'
require '../web/app/lib/RandomUtils.rb'
require '../pest/helper.AbstractFormExtended.rb'

$tests = []
$failed_tests = []

def add_test(name)
  $tests << name
  #puts name
end

def add_result(worked_fine)
  return if worked_fine
  $failed_tests << $tests.last
  #puts "Unfortunately, #{$tests.last} failed."
  #puts
end

OMR_OPTIONS = "-c #{number_of_processors-1} -t -d"
TEST_TMP_DIR = "../tmp/tests"

cdir = File.dirname(__FILE__)
Dir.chdir(cdir) do
  # delete old result files
  `find . -mindepth 3 -regex ".*[0-9]\.yaml" -delete`
  `find . -mindepth 3 -name "*comment.jpg" -delete`
  `find . -mindepth 3 -name "*DEBUG.jpg" -delete`

  # run OMR on the files
  Dir.glob("./omr-test/*.yaml") do |y|
    add_test("omr2.rb for #{y}")
    puts "./../pest/omr2.rb #{OMR_OPTIONS} -s #{y} -p #{y.gsub(/\.yaml/, "")}"
    system("./../pest/omr2.rb #{OMR_OPTIONS} -s #{y} -p #{y.gsub(/\.yaml/, "")}")
    add_result($?.exitstatus == 0)
  end

  # compare the newly generated results to the stored reference files
  Dir.glob("./omr-test/*/*_ref.yaml").each do |cmp|
    ref = YAML::load(File.read(cmp))
    new = YAML::load(File.read(cmp.gsub("_ref", "")))

    # get all boxes for each sheet for multi/single choice questions
    refq = ref.questions.select { |q| q.type == "square" }
    newq = new.questions.select { |q| q.type == "square" }
    refq.zip(newq).each do |rq, nq|
      rq.boxes.zip(nq.boxes).each do |rb, nb|
        name = "Cmp box on #{cmp}||#{nq.db_column}||#{rb.choice}"
        name << "  ||ref: #{rb.omr_result}   new: #{nb.omr_result}"
        add_test(name)
        add_result(rb.omr_result == nb.omr_result)
      end
    end

    # find all text questions
    refq = ref.questions.select { |q| q.type == "text" || q.type == "text_wholepage" }
    refq.each do |rq|
      ref_ex = [BOX_CHECKED, BOX_BARELY].include?(rq.boxes.first.omr_result)
      new_ex = File.exist?("#{cmp.gsub("_ref.yaml", "")}_#{rq.save_as}.jpg")

      add_test("Check if comment image exists #{cmp}//#{rq.db_column} | ref: #{ref_ex}   new: #{new_ex}")
      add_result(ref_ex == new_ex)
    end
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

  # store fails to disk for later comparison
  `mkdir -p #{TEST_TMP_DIR}/`
  `cd #{TEST_TMP_DIR} && mv -f omr-test-fails omr-test-fails-last`
  File.open("#{TEST_TMP_DIR}/omr-test-fails", 'w') do |f|
    $failed_tests.each { |t| f.write("* #{t}\n") }
  end
  if File.exist?("#{TEST_TMP_DIR}/omr-test-fails") and File.exist?("#{TEST_TMP_DIR}/omr-test-fails-last")
    puts "\n"*4
    puts "Compared to the last run, the following has changed:"
    puts `cd #{TEST_TMP_DIR} &&  diff -uw --suppress-common-lines omr-test-fails-last omr-test-fails `
  end
end




