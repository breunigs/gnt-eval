#!/usr/bin/env ruby

require 'web/app/lib/requirements.rb'
require 'dbi'

c = Course.find(134)

puts c.title
puts c.semester.title

f = YAML::load(File.read('lib/testform.yml'))

DBI.connect("DBI:#{f.db_backend}:#{f.db_db}", f.db_user, f.db_password) do |dbh|
  c.course_profs.each { |cp| cp.eval_against_form(f, dbh) }
end

