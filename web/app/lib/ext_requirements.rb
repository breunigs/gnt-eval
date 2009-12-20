#!/usr/bin/env ruby

require(File.join(File.dirname(__FILE__),'', 'database.rb'))
require(File.join(File.dirname(__FILE__),'', 'rails_requirements.rb'))
['semester', 'tutor', 'course', 'prof', 'course_prof', 'pic', 'c_pic'].each do |m|
  require (File.join(File.dirname(__FILE__),'../models', m))
end
