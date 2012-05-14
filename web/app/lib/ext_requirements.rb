# encoding: utf-8

require 'rubygems'
require 'pathname'
require 'action_mailer'
require 'active_record'


cdir = File.dirname(File.realdirpath(__FILE__))

require File.join(cdir, 'database.rb')
require File.join(cdir, '../../config/initializers', '001_requirements.rb')

['semester', 'tutor', 'course', 'prof', 'course_prof', 'pic', 'c_pic', 'postoffice', 'faculty', 'form'].each do |m|
  require (File.join(RAILS_ROOT ,'/app/models', m))
end
