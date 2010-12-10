#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'active_support'
require 'pathname'

module Seee
  module Config
    mattr_accessor :application_paths, :file_paths, :commands, :external_database, :settings, :custom_builds

    # Pfade für die custom-ImageMagick/RMagick Builds
    @@custom_builds = {
      # Unterordner, in dem alles gespeichert wird
      :dir => File.join(RAILS_ROOT, "..", "custom_build"),
    }
    @@custom_builds.merge!({
      # Pfade zum source code. Das * verhindert, dass man bei jedem
      # Versionsupdate die Config ändern muss
      :src_img_magick => File.join(@@custom_builds[:dir], "ImageMagick*"),
      :src_r_magick => File.join(@@custom_builds[:dir], "RMagick*"),
      :src_zbar => File.join(@@custom_builds[:dir], "zbarimg_hackup/zbar-0.10"),

      # Pfade, wohin die Programme installiert werden. Sollte nicht mit
      # dem * von oben matchen
      :bld_img_magick => File.join(@@custom_builds[:dir], "build_imagemagick"),
      :bld_r_magick => File.join(@@custom_builds[:dir], "build_rmagick"),
      :bld_zbar => File.join(@@custom_builds[:dir], "build_zbar"),
    })
    @@custom_builds.merge!({
      # Findet den Pfad der custom RMagick.rb, wenn diese installiert ist,
      # ansonsten nil. Eigentlich keine Einstellung, aber trotzdem ein guter
      # Ort um sie aufzubewahren.
      :rmagick_rb => Dir.glob(File.join(@@custom_builds[:bld_r_magick], "**", "RMagick.rb"))[0],
      # siehe auch @@file_paths[:rmagick]
    })

    # Die sollten recht selbsterklärend sein
    @@application_paths = {
      :hunspell => '/usr/bin/env hunspell',
      :pdflatex => '/home/jasper/texlive/2009/bin/x86_64-linux/pdflatex',
      # das ist das alte zbar, das die Standard ImageMagick Pfade nutzt
      :zbar_shared => File.join(RAILS_ROOT, '..', 'helfer', 'zbarimg'),
      # das ist das zbar, das gegen das eigene ImageMagick gelinkt wurde
      :zbar_cust => File.join(@@custom_builds[:bld_zbar], "bin", "zbarimg")
    }
    @@application_paths.merge!({
      # Nutze das eigene zbar wenn möglich
      :zbar => File.exists?(@@application_paths[:zbar_cust]) \
            ? @@application_paths[:zbar_cust]                \
            : @@application_paths[:zbar_shared],
    })

    # Externe Datenbank, in der die wirklichen Evaldaten gespeichert sind
    @@external_database = {
      :dbi_handler => 'Mysql',
      :username => 'eval',
      :password => 'E-Wahl',
      :database => 'eval'
    }

    @@settings = {
      # FQDN des standard-empfängers
      :standard_mail_domain => 'mathphys.fsk.uni-heidelberg.de',
      :standard_mail_from => 'evaluation@mathphys.fsk.uni-heidelberg.de',
      :standard_mail_bcc => 'evaluation@mathphys.fsk.uni-heidelberg.de',

      # defines how many sheets need to be handed in before a course or
      # tutor gets an evaluation. Otherwise a sheet might be matched to
      # the person who filled it in, destroying anonymity.
      :minimum_sheets_required => 3
    }
    @@file_paths = {
      # Verzeichnis, in dem die Kommentarbilder gespeichert
      # werden. Hat dann pro Semester Unterordner.
      :comment_images_public_dir => '/home/eval/public_html/.comments/',

      :texmfdir => File.join(RAILS_ROOT, '..', 'tex', 'bogen'),

      :hunspell_personal_dic => File.join(RAILS_ROOT, 'persdic.dic'),

      # Benutze die angepasste RMagick Version wenn möglich, ansonsten
      # falle auf die globale Version zurück (gedacht für "require")
      :rmagick => @@custom_builds[:rmagick_rb] || "RMagick"
    }

    # Spezielle Kommandos, die ggf. rechtespezifisch sind, also nicht
    # nur application_paths.

    @@commands = {
      :find_comment_image_directory => 'login_gruppe_home eval find',
      :mkdir_comment_image_directory => 'login_gruppe_home eval mkdir',

      :hunspell => @@application_paths[:hunspell] + " -d en_US,de_DE -p #{@@file_paths[:hunspell_personal_dic]}",

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
