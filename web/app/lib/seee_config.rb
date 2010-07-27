#!/usr/bin/env ruby

require 'active_support'

module Seee
  module Config
    mattr_accessor :application_paths
    @@application_paths = {
      :hunspell => '/usr/bin/env hunspell'
    }
  end
end
