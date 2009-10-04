#!/usr/bin/env ruby

require 'web/app/lib/ext_requirements.rb'
require 'dbi'

s = Semester.find(4)

DBI.connect('DBI:Mysql:eval', 'eval', 'E-Wahl') do |dbh| 
  puts s.evaluate(1, dbh)
end

