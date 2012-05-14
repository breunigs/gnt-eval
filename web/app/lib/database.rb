# encoding: utf-8

#!/usr/bin/env ruby

# DEPRECATED
# FIXME

#~ require 'active_record'
#~ require 'yaml'
#~ require 'logger'
#~ require 'erb'
#~
#~ require(File.join(File.dirname(__FILE__), 'mode.rb'))
#~ require(File.join(File.dirname(__FILE__), 'seee_config.rb'))
#~
#~ dbfile = File.join(File.dirname(__FILE__), '..', '..', 'config', 'database.yml')
#~
#~ puts "WTF"
#~ puts "WTF"
#~ puts "WTF"
#~ puts "WTF"
#~ puts "WTF"
#~ puts "WTF"
#~
#~
#~ dbconfig = YAML::load(ERB.new(IO.read(dbfile)).result)
#~
#~ puts "WTF"
#~ puts "WTF"
#~ puts "WTF"
#~ puts "WTF"
#~
#~ pp ENV
#~
#~ ActiveRecord::Base.establish_connection(dbconfig[ENV['RAILS_ENV']])
#~
#~ path=File.join(File.dirname(__FILE__), '../../log', 'database.log')
#~ `mkdir -p #{File.dirname(path)}`
#~ ActiveRecord::Base.logger = Logger.new(File.open(path, 'a+'))
