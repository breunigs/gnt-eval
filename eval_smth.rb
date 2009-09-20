#!/usr/bin/env ruby

require 'web/app/lib/ext_requirements.rb'
require 'dbi'

s = Semester.find(4)

f = YAML::load(File.read('lib/testform.yml'))

DBI.connect('DBI:Mysql:eval', 'eval', 'E-Wahl') do |dbh| 
  s.eval_against_form!(1, f, dbh)
end

