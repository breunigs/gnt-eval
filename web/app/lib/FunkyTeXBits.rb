#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'erb'

module FunkyTeXBits
  def spellcheck(code)
    # do nothing until we can fix this properly
    return code

    # check if hunspell is installed
    `#{Seee::Config.application_paths[:aspell]} --version`
    unless $?.to_i == 0
      logger.warn "aspell does not seem to be installed. Skipping spellcheck."
      return code
    end

    # write code to tempfile
    require 'digest'
    name = Digest::SHA256.hexdigest(code)
    path = File.join(temp_dir, "spellcheck_#{name}")
    File.open("#{path}", 'w') {|f| f.write(code) }

    # spell check!
    words = `cat #{path} | #{Seee::Config.commands[:aspell]}`.split("\n")

    unless $?.to_i == 0
      logger.warn "aspell failed for some reason. Exit code: #{$?}"
      logger.warn "aspell: #{Seee::Config.commands[:aspell]}"
      logger.warn "Path was: #{path}"
      logger.warn "Whole command: cat #{path} | #{Seee::Config.commands[:aspell]}"
      logger.warn "Code was: #{File.read(path)}"
      logger.warn "aspell output: #{words.join("\n")}"
      return code
    end
    File.delete(path)

    return code if words.empty?

    # highlight misspelled words
    w = words.join("|")
    r1 = Regexp.new(/.*\b(#{w})\b.*/)
    r2 = Regexp.new(/\b(#{w})\b/)
    blockers = Regexp.new(/\\pgf|\\spellingerror|\bpgf[a-z]+|\\color/)
    code.gsub!(r1) do |s|
      s.match(blockers).nil? ? s.gsub(r2, '\spellingerror{\1}') : s
    end

    code
  end

  def texpreview(code)
    return false, ["(no content)"], "", "" if code.nil? || code.strip.empty?

	require 'rubygems'
	require 'work_queue'
    require 'lib/RandomUtils.rb'
    require 'digest'

    name = Digest::SHA256.hexdigest(code)
    path = File.join(temp_dir, "preview_#{name}")

    # will be overwritten on (re-)generation
    failed = false
    exitcodes = []
    error = ""

    head = preamble("Blaming Someone For Bad LaTeX")
    head << "\\pagestyle{empty}"
    foot = "\\end{document}"

    File.open(path + ".tex", 'w') do |f|
      f.write(head + spellcheck(code) + foot)
    end

    error = `cd #{temp_dir} && #{Seee::Config.commands[:pdflatex_real]} #{path}.tex 2>&1`
    ex = $?.to_i + (File.exists?("#{path}.pdf") ? 0 : 1)
    error << "<hr><pre>" << head << spellcheck(code) << foot << "</pre>"
    exitcodes << ex

    if ex == 0
      # overwrite by design. Otherwise it's flooded with all
      # the TeX output even though TeXing worked fine
      error = ""

      # we don't really care if cropping worked or not
      exitcodes << (pdf_crop("#{path}.pdf") ? 0 : 1)

      error << `#{Seee::Config.application_paths[:convert]} -density 100 #{path}.pdf #{path}.png  2>&1`
      exitcodes << $?.to_i
      # convert creates one image per page, so join them
      # for easier processing
      unless File.exists?("#{path}.png")
        error << `#{Seee::Config.application_paths[:convert]} #{path}-*.png -append #{path}.png  2>&1`
        exitcodes << $?.to_i
      end
    end
    failed = (exitcodes.inject(0) { |sum,x| sum += x}) > 0

    # convert to base64
    if File.exists?("#{path}.png")
      require 'base64'
      data = File.open("#{path}.png", 'rb') { |f| f.read }
      base64 = Base64.encode64(data)
    end

    # cleanup temp files
    `rm -f "#{path}*"`

    return failed, exitcodes, error.gsub("\n", "<br/>"), base64
  end

  def t(item)
    # FIXME
    # all items that are translated here should be displayed in the
    # default language iff I18n is not tainted (i.e. mixed-language)
    #~ I18n.locale = I18n.default_locale if I18n.tainted?
    I18n.translate(item.to_sym)
  end

  def preamble(evalname, single = nil)
    data = IO.read(RAILS_ROOT + "/../tex/results_preamble.tex.erb")
    ERB.new(data).result(binding)
  end

  def TeXKopf(evalname, c_courses = 0, c_profs = 0, c_tutors = 0, c_forms = 0, single = nil)
    b = preamble(evalname, single)
    data = IO.read(RAILS_ROOT + "/../tex/results_header.tex.erb")
    b << ERB.new(data).result(binding)
    b
  end

  def TeXVorwort(facultylong, semestershort, semesterlong, single = nil)
    data = IO.read(RAILS_ROOT + "/../tex/results_preface.tex.erb")
    ERB.new(data).result(binding)
  end

  def TeXFuss(single = nil)
    path = File.join(Rails.root, "../tmp/sample_sheets/sample_")
    files = {}

    $curSem.forms.each do |f|
      f.languages.each do |l|
        files["#{path}#{f.id}_#{l}.pdf"] = { :name => f.name, :pages => f.pages.count }
      end
    end

    data = IO.read(RAILS_ROOT + "/../tex/results_footer.tex.erb")
    ERB.new(data).result(binding)
  end

  def blacklist_head(semester_title)
    b = ""
    b << "\\documentclass[11pt,a4paper]{article}\n"
    b << "\\usepackage[utf8]{inputenc}\n"
    b << "\\usepackage[T1]{fontenc}\n"
    b << "\\usepackage{graphicx}\n"
    b << "\\usepackage{longtable}\n"
    b << "\\usepackage{hyperref}\n"
    b << "\\usepackage[landscape]{geometry}\n"
    b << "\\title{Tutoren #{semester_title}}\n"
    b << "\\date{}\n"
    b << "\\begin{document}\n"
    b << "\\maketitle\n"
    b << "\\begin{longtable}{llrrrrr}\n"
    b << "\\hline\n"
    b << "Tutor & Vorlesung & Nutzen & Lehrer & Kompetenz & Vorbereitung & Bögen \\\\ \n"
    b << "\\hline\n"
    return b
  end
  def blacklist_foot
    "\\end{longtable}\\end{document}"
  end
end
