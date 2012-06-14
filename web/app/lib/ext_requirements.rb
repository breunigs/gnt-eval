# encoding: utf-8

if defined?(EXT_REQUIREMENTS_RAN)
  raise "Ext Requirements called twice"
end

EXT_REQUIREMENTS_RAN = 1

# RUBY_VERSION is frozen, but Gem::Version tries to modifiy it. Therefore
# we need a copy.
too_old = Gem::Version.new("1.9.2") > Gem::Version.new("#{RUBY_VERSION}")

raise "Ruby version is outdated. At least 1.9.2 is required but you are using #{RUBY_VERSION}" if too_old

#~ require 'rubygems'
#~ require 'pathname'
#~ require 'action_mailer'
require 'active_record'
require 'active_support'

cdir = File.dirname(File.realdirpath(__FILE__))

require File.join(cdir, "../../config/application.rb")


# Add load library dir to load path
$LOAD_PATH.unshift(cdir)

require "bundler/setup"
ENV["BUNDLE_GEMFILE"] = File.join(cdir, "../../../Gemfile")
Bundler.setup

# Load some basic initializers and all library fils
reqs = []
reqs << File.join(cdir, "../../config/initializers/001_requirements.rb")
reqs << File.join(cdir, "../../config/initializers/002_constants.rb")
reqs += Dir.glob(File.join(cdir, "*.rb"))

reqs.uniq.each do |d|
  next if d.end_with?(File.basename(__FILE__))
  require d
end


# Load Rails Modules on demand
Dir.glob(File.join(cdir, "../../app/models/*.rb")).each do |m|
  cls = File.basename(m, ".rb").classify.to_sym
  autoload cls, m
end
