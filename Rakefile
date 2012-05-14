# -*- coding: utf-8 -*-

require 'rubygems'
require 'action_mailer'
require './web/config/boot.rb'
require './lib/ext_requirements.rb'
require './lib/RandomUtils.rb'

require 'pp'
require 'yaml'

# needed for image manipulations
require 'RMagick'
require 'fileutils'

include Magick

require 'rake/clean'
CLEAN.include('tmp/**/*.log', 'tmp/**/*.out', 'tmp/**/*.aux',
  'tmp/**/*.toc', 'tmp/blame.tex', 'tmp/forms/**/*.tex')

# Capture ctrl+c and stop all currently running jobs in the work queue.
# needs current work_queue gem.
if work_queue.respond_to?("kill")
  trap("INT") { work_queue.kill; exit 99  }
else
  trap("INT") { exit 99  }
end


RT = ResultTools.instance unless defined?(RT)
SCap = Seee::Config.application_paths unless defined?(SCap)
SCc = Seee::Config.commands unless defined?(SCc)
SCfp = Seee::Config.file_paths unless defined?(SCfp)

# Creates a sample sheet in tmp/sample_sheets for the given form (object)
# and language name. Returns the full filepath, but without the file
# extension. Does not re-create existing files.
def make_sample_sheet(form, lang)
  # this is hardcoded throughout the project
  dir = "tmp/sample_sheets/"
  File.makedirs(dir)
  filename = "#{dir}sample_#{form.id}#{lang.to_s.empty? ? "" : "_#{lang}"}"

  form_misses_files = !File.exist?(filename+'.pdf') || !File.exist?(filename+'.yaml')
  # see if the form is newer than any of the files
  form_needs_regen = form_misses_files \
                      || form.updated_at > File.mtime(filename+'.pdf') \
                      || form.updated_at > File.mtime(filename+'.yaml')

  # PDFs are required for result generation and the posouts for OMR
  # parsing. Only skip if both files are present and newer than the
  # form itself.
  if !form_needs_regen && File.exists?(filename+'.pdf') && File.exists?(filename+'.yaml')
    puts "#{filename}.pdf already exists. Skipping."
    return filename
  end

  generate_barcode("0"*8, dir + "barcode00000000.pdf")

  File.open(filename + ".tex", "w") do |h|
    h << form.abstract_form.to_tex(lang)
  end

  puts "Wrote #{filename}.tex"
  tex_to_pdf("#{filename}.tex", true)
  `./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
  filename
end

# load external rakefiles
require './rakefiles/export.rb'
require './rakefiles/forms.rb'
require './rakefiles/images.rb'
require './rakefiles/import.rb'
require './rakefiles/mail.rb'
require './rakefiles/omr-test-helper.rb'
require './rakefiles/results.rb'
require './custom_build/build.rb'

# automatically calls rake -T when no task is given
task :default do
  puts "Choose your destiny:"
  system("rake -sT")
end

namespace :misc do
  desc "Generate how tos in all available languagess in tmp/howtos"
  task :howtos do
    saveto = File.join(GNT_ROOT, "tmp", "howtos")
    create_howtos(saveto)
    Rake::Task["clean".to_sym].invoke
  end

  desc "Export data from LSF in various ways helpful for our cause."
  task :lsfparse do
    # if you change stuff here, also adjust rakefiles/import.rb
    require "#{GNT_ROOT}/tools/lsf_parser_base.rb"
    puts "Finding IDs…"
    search = ["Mathematik und Informatik", "Fakultät für Physik und Astronomie"]
    mathe, physik = LSF.find_certain_roots(search)

    @dir = "tmp/lsfparse/"
    File.makedirs(@dir)

    def run(name, url)
      cmd = "cd '#{@dir}' && "
      cmd << "../../tools/lsf_parser_api.rb #{name} '#{url}' "
      cmd << "> #{name}.log"
      `#{cmd}`
    end
    puts "Gathering data…"
    work_queue.enqueue_b { run("mathe", mathe[:url]) }
    work_queue.enqueue_b { run("physik", physik[:url]) }
    work_queue.join
    puts
    puts "All Done. Have a look in #{@dir}"
  end


  desc "Generate lovely HTML output for our static website"
  task :static_output do
    courses = Semester.currently_active.map { |s| s.courses }.flatten
    puts courses.sort { |x,y| y.updated_at <=> x.updated_at }[0].updated_at
    # Sort by faculty first, then by course title
    sorted = courses.sort do |x,y|
      if x.faculty_id == y.faculty_id
        x.title <=> y.title
      else
        x.faculty_id <=> y.faculty_id
      end
    end
    facs = Faculty.find(:all)
    fac_id = -1

    def printTD(stuff, join = ", ", extra = "")
      s = "<td>" if extra.empty?
      s = "<td style=\"#{extra}\">" unless extra.empty?
      if stuff.is_a? Array
        s << stuff.join(join) unless stuff.empty?
      elsif stuff.is_a? String
        s << stuff
      end
      s << "</td>"
      s
    end

    odd = true
    sorted.each do |c|
      # faculty changed, so print header
      if fac_id != c.faculty_id
        fname = facs.find { |f| f.id == c.faculty_id }.longname
        puts "</table>" unless fac_id == -1
        puts "<h2>#{fname}</h2>"
        puts "<table class=\"aligntop\" summary=\"Veranstaltungen der Fakultät für #{fname}\">"
        puts "<tr class=\"odd\">"
        puts "<th></th>"
        puts "<th>Veranstaltung</th>"
        puts "<th>DozentInnen</th>"
        puts "<th>Wann?</th>"
        puts "<th>Tutoren</th></tr>"
      end
      puts "<tr>" if odd
      puts "<tr class=\"odd\">" if !odd
      tuts = c.tutors.collect{ |t| t.abbr_name }
      profs = c.profs.collect{ |t| t.fullname }
      hasEval = c.fs_contact_addresses.empty? ? "&nbsp;" : "&#x2713;"

      puts printTD(hasEval)
      puts printTD(c.title.gsub("&", "&amp;"))
      puts printTD(profs, "<br/>", "white-space: nowrap")
      puts printTD(c.description)
      puts printTD(tuts)
      puts "</tr>"
      fac_id = c.faculty_id
      odd = !odd
    end
    puts "</table>"
  end

end

rule '.pdf' => '.tex' do |t|
  warn "Rakefile pdf→tex rule is deprecated. Use tex_to_pdf(filename) directly."
  tex_to_pdf(t.source)
end
