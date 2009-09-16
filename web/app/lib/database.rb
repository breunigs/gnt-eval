#!/usr/bin/env ruby

require 'active_record'
require 'yaml'
require 'logger'

dbconfig = YAML::load(File.open(File.join(File.dirname(__FILE__),'../../config', 'database.yml')))
ActiveRecord::Base.establish_connection(dbconfig['development'])
ActiveRecord::Base.logger = Logger.new(File.open(File.join(File.dirname(__FILE__), '../../log', 'database.log'), 'a'))
