#!/usr/bin/env ruby

require 'active_record'
require 'yaml'
require 'logger'
require 'erb'

require(File.join(File.dirname(__FILE__), 'mode.rb'))
require(File.join(File.dirname(__FILE__), 'seee_config.rb'))

dbfile = File.join(File.dirname(__FILE__), '..', '..', 'config', 'database.yml')
dbconfig = YAML::load(ERB.new(IO.read(dbfile)).result)
ActiveRecord::Base.establish_connection(dbconfig[ENV['RAILS_ENV']]))
ActiveRecord::Base.logger = Logger.new(File.open(File.join(File.dirname(__FILE__), '../../log', 'database.log'), 'a'))
