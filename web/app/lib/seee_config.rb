#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'active_support'

module Seee
  module Config
    mattr_accessor :application_paths, :file_paths, :commands

    # Die sollten recht selbsterklärend sein
    @@application_paths = {
      :hunspell => '/usr/bin/env hunspell'
    }

    @@file_paths = {
      # Verzeichnis, in dem die Kommentarbilder gespeichert
      # werden. Hat dann pro Semester Unterordner.
      :comment_images_public_dir = '/home/eval/public_html/.comments/'
    }

    # Spezielle Kommandos, die ggf. rechtespezifisch sind, also nicht
    # nur application_paths. FIXME: command[:hunspell] sollte, falls
    # nicht gesetzt, auf appliction_paths defaulten
    @@commands = {
      :mkdir_comment_image_directory = 'login_gruppe_home eval mkdir',
      :find_comment_image_directory = 'login_gruppe_home eval find'
    }
  end
end
