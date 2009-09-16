#!/usr/bin/env ruby

require 'app/web/lib/requirements.rb'

c = Course.find(134)

puts c.title
