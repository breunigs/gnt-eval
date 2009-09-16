#!/usr/bin/env ruby

require(File.join(File.dirname(__FILE__),'', 'database.rb'))
require(File.join(File.dirname(__FILE__),'', 'TeXQuestion.rb'))
require(File.join(File.dirname(__FILE__),'', 'Form.rb'))
['semester', 'tutor', 'course', 'prof', 'course_prof', 'pic'].each do |m|
  require (File.join(File.dirname(__FILE__),'../models', m))
end
