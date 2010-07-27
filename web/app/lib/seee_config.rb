#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'active_support'

module Seee
  module Config
    mattr_accessor :application_paths, :file_paths, :commands, :external_database

    # Die sollten recht selbsterklärend sein
    @@application_paths = {
      :hunspell => '/usr/bin/env hunspell',
      :pdflatex => '/home/jasper/texlive/2009/bin/x86_64-linux/pdflatex',
      :zbar => 'FIXME'
    }

    # Externe Datenbank, in der die wirklichen Evaldaten gespeichert sind
    @@external_database = {
      :dbi_handler => 'Mysql',
      :username => 'eval',
      :password => 'E-Wahl',
      :database => 'eval'
    }

    @@file_paths = {
      # Verzeichnis, in dem die Kommentarbilder gespeichert
      # werden. Hat dann pro Semester Unterordner.
      :comment_images_public_dir => '/home/eval/public_html/.comments/',

      :texmfdir => File.expand_path(
                     File.join(
                       File.dirname(Pathname.new(__FILE__).realpath),
                         '..', '..', '..', 'tex', 'bogen')),
      
      :hunspell_personal_dic => File.join(
                                  File.dirname(Pathname.new(__FILE__).realpath),
                                  'persdic.dic')
    }

    # Spezielle Kommandos, die ggf. rechtespezifisch sind, also nicht
    # nur application_paths.

    @@commands = {
      :find_comment_image_directory => 'login_gruppe_home eval find',
      :mkdir_comment_image_directory => 'login_gruppe_home eval mkdir',

      :hunspell => @@application_paths[:hunspell] + ' -d en_US,de_DE -p #{@@file_paths[:hunspell_personal_dic]}',

      # -halt-on-error: stops TeX after the first error
      # -file-line-error: displays file and line where the error occured
      # -draftmode: doesn't create PDF, which speeds up TeX. Still does
      #             syntax-checking and toc-creation
      # -interaction=nonstopmode prevents from asking for stuff on the
      #             console which regularily occurs for missing packages
      :pdflatex => "TEXMFHOME=#{@@file_paths[:texmfdir]} #{@@application_paths[:pdflatex]}"}
    @@commands.merge!({
      :pdflatex_fast => @@commands[:pdflatex].to_s + ' -halt-on-error -file-line-error -draftmode -interaction=nonstopmode',
      :pdflatex_real => @@commands[:pdflatex].to_s + ' -halt-on-error -file-line-error',

      :zbar => @@application_paths[:zbar].to_s + ' --set ean13.disable=1 --set upce.disable=1 --set isbn10.disable=1 --set upca.disable=1 --set isbn13.disable=1 --set i25.disable=1 --set code39.disable=1 --set code128.disable=1 --set y-density=4 '
    })

    # Sind Kommandos nicht näher spezifiziert, versuchen wir es
    # einfach mit dem Applikationspfad
    def @@commands.default(key=nil)
      @@application_paths[key]
    end

    # Sind Pfade nicht gesetzt, defaulte auf /usr/bin/env
    def @@application_paths.default(key=nil)
      if not key.nil?
        "/usr/bin/env #{key.to_s}"
      else
        nil
      end
    end
  end
end
