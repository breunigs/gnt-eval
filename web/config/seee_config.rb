# encoding: utf-8

########################################################################
# HOW 2 CONFIG
########################################################################
# This is the default configuration file, which is checked into the
# repository. It will load the system and user configuration files, if
# they exist, from the following locations:
system_config = "/etc/gnt-eval-seee.rb"
user_config =  "~/.gnt-eval-seee.rb"
# The user’s one takes precedence over the system wide one which takes
# precedence over this default file. Here’s a skeleton to start your own
# configuration file:
#
# module Seee
#   module Config
#     @@custom_builds.merge!({
#       :some_setting => "jasper ist doof",  # note the comma!
#       :some_other_setting => "stefan ist doof"
#     })
#     @@application_paths.merge!({
#       :some_setting => "oliver/ist/doof"
#     })
#     @@external_database.merge!({
#     })
#     @@settings.merge!({
#     })
#     @@file_paths.merge!({
#     })
#     @@commands.merge!({
#     })
#   end
# end
########################################################################

require 'rails/all'
require 'pathname'

if not defined?(RAILS_ROOT)
  RAILS_ROOT = File.join(File.dirname(__FILE__), "..")
end

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
      :rmagick_rb => Dir.glob(File.join(@@custom_builds[:bld_r_magick], "**", "RMagick.rb"), File::FNM_DOTMATCH)[0],
      # see also: @@file_paths[:rmagick]
    })

    @@application_paths = {
      :hunspell => 'hunspell',
      :pdflatex => 'pdflatex',
      # point this to the script you use to import pages as 2-sided tif
      # images. Either name them ".tif" (NOT tif_f_) if you want them to
      # be recognized or send patches :)
      :scan => File.join(RAILS_ROOT, '..', 'tools', "scan.sh"),
      # point this to the script that can be used to print forms. It
      # should accept file paths to PDF files to print and be non-
      # interactive if --non-interactive is given on the command line.
      # If no arguments are given, have it print files in tmp/forms/*pdf
      # that do not start with " multiple" (note the leading space).
      :print => File.join(RAILS_ROOT, '..', 'tools', 'print_forms_locally.rb'),
      # Point this to your preferred PDF Viewer. It is recommended to
      # choose one which can detect if it is already showing the same
      # image instead of opening it again as well as detect changes to
      # the source file.
      :pdf_viewer => "evince",
      # this is the old zbar, which uses the default ImageMagick
      :zbar_shared => File.join(RAILS_ROOT, '..', 'tools', "zbarimg_#{`uname -m`.strip}"),
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
      :dbi_handler => 'Pg',
      :username => 'gnt-eval',
      :password => 'gnt-eval',
      :database => 'results'
    }

    @@settings = {
      # set to true if the tutors should be censored as well if one of the profs
      # of a course has not agreed to publish their results. In our case, we will
      # have all tutors sign the publish agreement so we don't need to track this
      # per tutor.
      :censor_tutors_with_course => true,
      
      # default recipient's FQDN
      :standard_mail_domain => 'some.domain.name.asdf',
      :standard_mail_from => 'evaluation@some.domain.name.asdf',
      :standard_mail_bcc => 'evaluation@some.domain.name.asdf',

      # who is responsible for the resulting PDF files? _headline will
      # be displayed at the title page, _pdf will be put into PDF meta
      # data.
      :author_page_headline => "Universität Heidelberg\\\\Fachschaft MathPhys",
      :author_pdf => "Fachschaft MathPhys, Universität Heidelberg",

      # defines how many sheets need to be handed in before a course or
      # tutor gets an evaluation. Otherwise a sheet might be matched to
      # the person who filled it in, destroying anonymity.
      :minimum_sheets_required => 5,

      # Set the default locale that will be used for the result PDFs. If
      # no locale is given on the command line, courses will be printed
      # in their selected language and all other pieces of text in the
      # language below.
      :default_locale => :en,

      # how many sheets should be printed when running emergency print
      :emergency_printing_amount => 50
    }

    @@file_paths = {
      # Specify a directory where to cache things
      :cache_tmp_dir => '/tmp/seee/',

      # directory to store the extracted comment images in. Each term
      # has its own subfolder, which will be created automatically.
      :comment_images_public_dir  => File.join(RAILS_ROOT, "public", "comments"),

      # Same directory as above, but available via http
      :comment_images_public_link => "http://localhost:3000/comments",

      # public URL to the seee web gui. It’s required in order to
      # generate the correct links on the cover sheets.
      :web_gui_public_link => "http://localhost:3000/",

      # the directory where the final form pdf files will be stored.
      # this location will be printed below each howto, in case additional
      # sheets need to be printed.
      :forms_howto_dir => File.join(RAILS_ROOT, "..", "tmp", "forms"),

      :texmfdir => File.join(RAILS_ROOT, '..', 'tex', 'bogen'),

      :hunspell_personal_dic => File.join(RAILS_ROOT, "app", "lib", "persdic.dic"),

      :scanned_pages_dir => File.join(RAILS_ROOT, "..", "tmp", "scanned"),

      :sorted_pages_dir => File.join(RAILS_ROOT, "..", "tmp", "images"),

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

    # special commands which might be access right depended, i.e.
    # anything that is more than an “application_path”

    @@commands = {
      :cp_comment_image_directory => 'cp',
      :mkdir_comment_image_directory => 'mkdir',

      :hunspell => "#{@@application_paths[:hunspell]} -t -l -d en_US,de_DE -p #{@@file_paths[:hunspell_personal_dic]}",
      :aspell => "#{@@application_paths[:aspell]} -t -d de_DE-neu list | #{@@application_paths[:aspell]} -t -d en list",

      :pdflatex => "TEXMFHOME=#{@@file_paths[:texmfdir]} #{@@application_paths[:pdflatex]}",

      :xelatex => "#{@@application_paths[:xelatex]} -halt-on-error -file-line-error -interaction=nonstopmode",

      # disable unused barcodes and disable scanning in x-direction to speed up processing.
      :zbar => "#{@@application_paths[:zbar]} --set ean13.disable=1 --set upce.disable=1 --set isbn10.disable=1 --set upca.disable=1 --set isbn13.disable=1 --set i25.disable=1 --set code39.disable=1 --set code128.disable=1 --set y-density=4 --set x-density=0 "
    }

    @@commands.merge!({
      # scan every line to hopefully find more barcodes
      :zbar_desperate => "#{@@commands[:zbar]} --set y-density=1 ",

      # -halt-on-error: stops TeX after the first error
      # -file-line-error: displays file and line where the error occured
      # -draftmode: doesn't create PDF, which speeds up TeX. Still does
      #             syntax-checking and toc-creation
      # -interaction=nonstopmode prevents from asking for stuff on the
      #             console which regularily occurs for missing packages
      :pdflatex_fast => "#{@@commands[:pdflatex]} -halt-on-error -file-line-error -draftmode -interaction=nonstopmode",
      :pdflatex_real => "#{@@commands[:pdflatex]} -halt-on-error -file-line-error"
    })

    # fall back to application_paths if a command
    # hasn't been configured/is unspecified
    def @@commands.default(key=nil)
      @@application_paths[key]
    end
  end
end

# Load configuration files from other directories.
system_config = File.expand_path(system_config)
load system_config if File.exist? system_config


begin
  user_config = File.expand_path(user_config)
  load user_config if File.exist? user_config
rescue
  # If you get this error, it probably means that expand path failed
  # because either the path invalid (e.g. unescaped tildes that cannot
  # be expanded) or no home directory is set. The latter is usually true
  # if gnt-eval is run from Apache.
end

# some commonly used shorthands
Scc = Seee::Config.commands
SCed = Seee::Config.external_database
