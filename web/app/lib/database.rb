#!/usr/bin/env ruby

require 'active_record'
require 'yaml'
require 'logger'

dbconfig = YAML::load(File.open('config/database.yml'))

ActiveRecord::Base.establish_connection(dbconfig['internal'])
ActiveRecord::Base.logger = Logger.new(File.open('log/database.log', 'a'))
