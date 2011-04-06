#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'active_support'
require 'pathname'

module Seee
  module Config
    mattr_accessor :application_paths, :file_paths, :commands, :external_database, :settings, :custom_builds

    # paths for custom-ImageMagick/RMagick builds
    @@custom_builds = {
      # subfolder to save all build-related stuff to
      :dir => File.join(RAILS_ROOT, "..", "custom_build"),
    }
    @@custom_builds.merge!({
      # paths to the sources. The * saves us from having to change the
      # config on upstream updates
      :src_img_magick => File.join(@@custom_builds[:dir], "ImageMagick*"),
      :src_r_magick => File.join(@@custom_builds[:dir], "RMagick*"),
      :src_zbar => File.join(@@custom_builds[:dir], "zbarimg_hackup/zbar-0.10"),

      # defines the paths where the builds should be installed to. This should
      # not match on the * from above.
      :bld_img_magick => File.join(@@custom_builds[:dir], "build_imagemagick"),
      :bld_r_magick => File.join(@@custom_builds[:dir], "build_rmagick"),
      :bld_zbar => File.join(@@custom_builds[:dir], "build_zbar"),
    })
    @@custom_builds.merge!({
      # contains the path to the custom RMagick.rb if it has been built. It's
      # nil otherwise. While this is not actually a pref, it seems to be in a
      # good place.
      :rmagick_rb => Dir.glob(File.join(@@custom_builds[:bld_r_magick], "**", "RMagick.rb"))[0],
      # see also: @@file_paths[:rmagick]
    })

    # these pretty much speak for themselves
    @@application_paths = {
      :hunspell => '/usr/bin/hunspell',
      :pdflatex => '/home/jasper/texlive/2009/bin/x86_64-linux/pdflatex',
      # this is the old zbar, which uses the default ImageMagick
      :zbar_shared => File.join(RAILS_ROOT, '..', 'helfer', "zbarimg_#{`uname -m`.strip}"),
      # this is the custom zbar, which uses the custom ImageMagick
      :zbar_cust => File.join(@@custom_builds[:bld_zbar], "bin", "zbarimg")
    }
    @@application_paths.merge!({
      # prefer own zbar over the default one
      :zbar => File.exists?(@@application_paths[:zbar_cust]) \
            ? @@application_paths[:zbar_cust]                \
            : @@application_paths[:zbar_shared],
    })

    # external database (i.e. not the Rails one) which stores the real eval data
    @@external_database = {
      :dbi_handler => 'Mysql',
      :username => 'eval',
      :password => 'E-Wahl',
      :database => 'eval'
    }

    @@settings = {
      # default recipient's FQDN
      :standard_mail_domain => 'mathphys.fsk.uni-heidelberg.de',
      :standard_mail_from => 'evaluation@mathphys.fsk.uni-heidelberg.de',
      :standard_mail_bcc => 'evaluation@mathphys.fsk.uni-heidelberg.de',

      # defines how many sheets need to be handed in before a course or
      # tutor gets an evaluation. Otherwise a sheet might be matched to
      # the person who filled it in, destroying anonymity.
      :minimum_sheets_required => 3
    }
    @@file_paths = {
      # Specify a directory where to cache things
      :cache_tmp_dir => '/tmp/seee/',

      # directory to store the extracted comment images to. Each semester
      # has its own subfolder.
      :comment_images_public_dir => '/home/eval/public_html/.comments/',

      # Same directory as above, but available via http
      :comment_images_public_link => 'http://mathphys.fsk.uni-heidelberg.de/~eval/.comments/',

      # the directory where the final form pdf files will be stored.
      # this location will be printed below each howto, in case additional
      # sheets need to be printed.
      :forms_howto_dir => '/home/eval/forms/',

      :texmfdir => File.join(RAILS_ROOT, '..', 'tex', 'bogen'),

      :hunspell_personal_dic => File.join(Rails.root, 'app/lib/persdic.dic'),

      # prefer the custom RMagick version over the default one. Its meant
      # to be used for "require" and should automatically fall back to
      # default if custom build is not available.
      :rmagick => @@custom_builds[:rmagick_rb] || "RMagick"
    }


    # Ask /usr/bin/env for unconfigured/unspecified paths
    def @@application_paths.default(key=nil)
      if not key.nil?
        "/usr/bin/env #{key.to_s}"
      else
        nil
      end
    end

    # special commands which might be access right depended. I.e. anything
    # that is more than an “application_path”

    @@commands = {
      :cp_comment_image_directory => 'login_gruppe_home eval cp',
      :mkdir_comment_image_directory => 'login_gruppe_home eval mkdir',

      :hunspell => @@application_paths[:hunspell] + " -d en_US,de_DE -p #{@@file_paths[:hunspell_personal_dic]}",
      :aspell => @@application_paths[:aspell] + " -t -d de_DE-neu list | " + @@application_paths[:aspell] + " -t -d en list",

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

    # fall back to application_paths if a command
    # hasn't been configured/is unspecified
    def @@commands.default(key=nil)
      @@application_paths[key]
    end
  end
end
