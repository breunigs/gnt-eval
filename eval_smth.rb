#!/usr/bin/env ruby

require 'web/app/lib/ext_requirements.rb'
require 'dbi'

s = Semester.find(4)

f = YAML::load(File.read('lib/testform.yml'))

DBI.connect("DBI:#{f.db_backend}:#{f.db_db}", f.db_user, f.db_password) do |dbh|
  s.eval_against_form!(1, f, dbh)
end

