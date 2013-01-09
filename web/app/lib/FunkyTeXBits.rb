# encoding: utf-8

cdir = File.dirname(File.realdirpath(__FILE__))
require 'rubygems'
require 'erb'
require 'work_queue'
require File.join(cdir, 'RandomUtils.rb')
require File.join(cdir, 'result_tools.rb')
require 'digest'

module FunkyTeXBits
  def spellcheck(code)
    begin
      # check if hunspell is installed
      `#{Seee::Config.application_paths[:hunspell]} --version &> /dev/null`
      unless $?.to_i == 0
        logger.warn "hunspell does not seem to be installed. Skipping spellcheck."
        return code
      end

      # write code to tempfile
      name = Digest::SHA256.hexdigest(code)
      path = File.join(temp_dir, "spellcheck_#{name}")
      File.open("#{path}", 'w') {|f| f.write(code) }

      # spell check!
      words = `cat #{path} | #{Seee::Config.commands[:hunspell]} 2> /dev/null`.split("\n")

      unless $?.to_i == 0
        logger.warn "hunspell failed for some reason. Exit code: #{$?}"
        logger.warn "hunspell: #{Seee::Config.commands[:hunspell]}"
        logger.warn "Path was: #{path}"
        logger.warn "Whole command: cat #{path} | #{Seee::Config.commands[:hunspell]}"
        logger.warn "Code was: #{File.read(path)}"
        logger.warn "hunspell output: #{words.join("\n")}"
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
    rescue; end
    code
  end

  # returns # of lines the code given to texpreview will be offset. This
  # can be used to correct the display to correspond to the actual lines
  # as they will be in the TeX file.
  def texpreview_header_offset
    evalname = ""
    l = ERB.new(RT.load_tex("preamble")).result(binding).split("\n").size
    l + 3
  end

  def texpreview(code)
    return false, ["(no content)"], "", "" if code.nil? || code.strip.empty?

    exec_time_start = Time.now

    name = Digest::SHA256.hexdigest(code)
    path = File.join(temp_dir, "preview_#{name}")

    # will be overwritten on (re-)generation
    failed = false
    exitcodes = []
    error = ""

    evalname = "Blaming Someone For Bad LaTeX"
    additional_packages = "\\usepackage[active,displaymath,floats,textmath,graphics,sections,tightpage]{preview}\n"

    head = ERB.new(RT.load_tex("preamble")).result(binding)
    head << "\\pagestyle{empty}\n\\begin{preview}\n"
    foot = "\n\\end{preview}\n\\end{document}"

    File.open(path + ".tex", 'w') do |f|
      f.write(head + spellcheck(code) + foot)
    end

    logger.debug "TEX PREVIEW: Setup Phase #{Time.now - exec_time_start}" if logger
    exec_time_start = Time.now

    error = `cd #{temp_dir} && #{Seee::Config.commands[:pdflatex_real]} "#{path}.tex" 2>&1`
    ex = $?.to_i + (File.exists?("#{path}.pdf") ? 0 : 1)
    error << "<hr><pre>" << head << spellcheck(code) << foot << "</pre>"
    exitcodes << ex

    logger.debug "TEX PREVIEW: PDF Render #{Time.now - exec_time_start}" if logger
    exec_time_start = Time.now

    if ex == 0
      error << `#{Seee::Config.application_paths[:convert]} -density 100 "#{path}.pdf" "#{path}.png"  2>&1`
      exitcodes << $?.to_i
      logger.debug "TEX PREVIEW: PDF to PNG #{Time.now - exec_time_start}" if logger
      exec_time_start = Time.now
    end
    failed = (exitcodes.inject(0) { |sum,x| sum += x}) > 0

    # convert to base64
    if File.exists?("#{path}.png")
      require 'base64'
      data = File.open("#{path}.png", 'rb') { |f| f.read }
      base64 = Base64.encode64(data)
      logger.debug "TEX PREVIEW: PNG to Base64 #{Time.now - exec_time_start}" if logger
      exec_time_start = Time.now
    end

    # cleanup temp files
    files = '"' + Dir.glob("#{path}*").join('" "') + '"'
    `rm -f #{files}`

    # beautify error output. If there’s a TeX error it will remove the
    # stuff TeX prints before it encounters the error.
    error.encode!('UTF-8', 'UTF-8', :invalid => :replace)
    e = error.split("\n" + path[0..77], 2)
    error = "\n" + path[0..77] + e.last if e.size == 2
    # highlight likely TeX errors
    error.gsub!(/(^.*\nl.[0-9]+.*)/, "<span class=\"red\">\\0</span>")

    logger.debug "TEX PREVIEW: Cleanup #{Time.now - exec_time_start}" if logger
    logger.debug "TEX PREVIEW: Base64 size: #{base64.size}" if base64

    return failed, exitcodes, error.gsub(/[\n\r]+/, "<br/>"), base64
  end

  def t(item)
    # FIXME
    # all items that are translated here should be displayed in the
    # default language iff I18n is not tainted (i.e. mixed-language)
    #~ I18n.locale = I18n.default_locale if I18n.tainted?
    I18n.translate(item.to_sym)
  end
end
