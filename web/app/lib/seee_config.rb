#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'active_support'

module Seee
  module Config
    mattr_accessor :application_paths, :file_paths, :commands

    # Die sollten recht selbsterklärend sein
    @@application_paths = {
      :hunspell => '/usr/bin/env hunspell',
      :pdflatex => '/home/jasper/texlive/2009/bin/x86_64-linux/pdflatex',
      :zbar => 'GOTTA DO THIS'
    }

    @@file_paths = {
      # Verzeichnis, in dem die Kommentarbilder gespeichert
      # werden. Hat dann pro Semester Unterordner.
      :comment_images_public_dir => '/home/eval/public_html/.comments/'
    }

    # Spezielle Kommandos, die ggf. rechtespezifisch sind, also nicht
    # nur application_paths. FIXME: command[:hunspell] sollte, falls
    # nicht gesetzt, auf appliction_paths defaulten

    # Korrektes TexMF finden
    texmfdir = File.dirname(Pathname.new(__FILE__).realpath)
    texmfdir = File.join(texmfdir, "..", "..", "..", "tex", "bogen")
    texmfdir = File.expand_path(texmfdir)

    @@commands = {
      :find_comment_image_directory => 'login_gruppe_home eval find',
      :mkdir_comment_image_directory => 'login_gruppe_home eval mkdir',

      # -halt-on-error: stops TeX after the first error
      # -file-line-error: displays file and line where the error occured
      # -draftmode: doesn't create PDF, which speeds up TeX. Still does
      #             syntax-checking and toc-creation
      # -interaction=nonstopmode prevents from asking for stuff on the
      #             console which regularily occurs for missing packages
      :pdflatex => "TEXMFHOME=#{texmfdir} #{@@application_paths[:pdflatex]}"}
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
  end
end
