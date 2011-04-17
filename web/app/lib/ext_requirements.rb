#!/usr/bin/env ruby

require 'rubygems'
require 'action_mailer'

require(File.join(File.dirname(__FILE__), 'database.rb'))
require(File.join(File.dirname(__FILE__), 'rails_requirements.rb'))
['semester', 'tutor', 'course', 'prof', 'course_prof', 'pic', 'c_pic', 'postoffice', 'faculty', 'form'].each do |m|
  require (File.join(Rails.root ,'/app/models', m))
end
