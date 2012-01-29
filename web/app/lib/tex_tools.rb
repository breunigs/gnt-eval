# -*- coding: utf-8 -*-
# home to all TeX related tools that might be used in more than one
# location.

require 'erb'

class String
  # Removes all UTF8 chars and replaces them by underscores. Usually
  # required for LaTeX output.
  def to_ascii
    self.gsub(/[\x80-\xff]/, "_")
  end

  # escapes & _ # and % signs if not already done so
  def escape_for_tex
    s = self.gsub(/\\?&/, '\\\&').gsub(/\\?%/, '\\\%')
    s.gsub(/\\?_/, '\\\_').gsub(/\\?#/, '\\\#')
  end

  # strips TeX tags that are commonly used when designing a form so the
  # text actually fits into the sheet. Most likely, these tags are not
  # required in the results, therefore they may be stripped here. It
  # does not remove superfluous curly braces because that would be more
  # effort… also TeX, doesn’t care about them… Currently removes:
  # \linebreak, \mbox, \textls, \hspace*, \hspace.
  # In case a line ends with an hyphen like this: long-\linebreak{}word
  # the hypen will be removed as well.
  def strip_common_tex
    s = self.gsub(/-\\linebreak(\{\})?/, "") # no space due to hyphen
    s = s.gsub(/\\linebreak(\{\})?/, " ")    # no hypen, so add space
    s = s.gsub(/\\mbox/, "")
    s = s.gsub(/\\textls\[-?[0-9]+\]/, "")
    s = s.gsub(/\\hspace\*?\{[^\}]+\}/, "")
  end

  # Fixes some often encountered errors in TeX Code.
  def fix_common_tex_errors
    # _ → \_, '" → "', `" → "`
    code = self.gsub(/([^\\])_/, '\1\\_').gsub(/`"/,'"`').gsub(/'"/, '"\'')
    # correct common typos
    code = code.gsub("\\textit", "\\emph")
    code = code.gsub("{itemsize}", "{itemize}").gsub("/begin{", "\\begin{")
    code = code.gsub("/end{", "\\end{").gsub("/item ", "\\item ")
    code = code.gsub("\\beign", "\\begin").gsub(/[.]{3,}/, "\\dots ")
    code
  end

  # Returns array of warning messages that might be bugs
  def warn_about_possible_tex_errors
    msg = []

    msg << "Plain (i.e. \") quotation mark use?" if self.match("\"")
    msg << "Unexpanded “&”?" if self.match("\\&")
    msg << "Deprecated quotation mark use?" if self.match("\"`")
    msg << "Deprecated quotation mark use?" if self.match("\"'")
    msg << "Underline mustn't be used. Ever." if self.match("\\underline")
    msg << "Unescaped %-signs?" if self.match(/[^\\]%/)

    begs = self.scan(/\\begin\{[a-z]+?\}/)
    ends = self.scan(/\\end\{[a-z]+?\}/)
    if  begs.count != ends.count
	msg << "\\begin and \\end count differs. This is what has been found:"
	msg << "\tBegins: #{begs.join("\t")}"
	msg << "\tEnds:   #{ends.join("\t")}"
    end

    msg.collect { |x| "\t" + x }.join("\n")
  end
end


# Renders the given TeX Code directly into a PDF file at the given
# location
def render_tex(tex_code, pdf_path, include_head=true)
  I18n.load_path += Dir.glob(File.join(RAILS_ROOT, '/config/locales/*.yml'))
  I18n.load_path.uniq!

  pdf_path = File.expand_path(pdf_path)

  id = File.basename(pdf_path, ".pdf")

  # use normal result.pdf preamble
  if include_head
    def t(t); I18n.t(t); end
    evalname = "#{id} (#{pdf_path})"
    head = ERB.new(RT.load_tex("preamble")).result(binding)
    tex_code = head + tex_code + '\end{document}'
  end

  tmp = File.join(temp_dir(id), "#{id}.tex")
  File.open(tmp, 'w') {|f| f.write(tex_code) }

  if tex_to_pdf(tmp) and File.exists?(tmp)
    File.makedirs(File.dirname(pdf_path))
    FileUtils.mv(tmp.gsub(/\.tex$/, ".pdf"), pdf_path)
    puts
    puts "Done, have a look at #{pdf_path}"
  else
    puts "Rendering your TeX Code failed."
  end
end

# Takes path to tex file as input and will run pdflatex on it. Will exit
# the program in case of en error. Returns nothing. Will overwrite
# existing files. Set one_time to true if there are no references and
# it’s sufficient to run pdflatex only once.
def tex_to_pdf(file, one_time = false)
  filename="\"#{File.basename(file)}\""
  texpath="cd \"#{File.dirname(file)}\" && "

  first = Scc[one_time ? :pdflatex_real : :pdflatex_fast]

  # run it once fast, to see if there are any syntax errors in the
  # text and create first-run-toc
  err = `#{texpath} #{first} #{filename} 2>&1`
  if $?.exitstatus != 0
      warn "="*60
      warn err
      warn "\n\n\nERROR WRITING: #{file}"
      warn "EXIT CODE: #{$?}"
      warn "COMMAND: #{texpath} #{first} #{filename}"
      warn "="*60
      warn "Running 'rake results:find_broken_comments' or 'rake results:fix_tex_errors' might help."
      raise
  end

  unless one_time
    # run it fast a second time, to get /all/ references correct
    `#{texpath} #{Scc[:pdflatex_fast]} #{filename} 2>&1`
    # now all references should have been resolved. Run it a last time,
    # but this time also output a pdf
    `#{texpath} #{Scc[:pdflatex_real]} #{filename} 2>&1`
  end

  if $?.exitstatus == 0
      puts "Wrote #{file.gsub(/\.tex$/, ".pdf")}"
      true
  else
      warn "Some other error occured. It shouldn’t be TeX-related, as"
      warn "it already passed one run. Well, happy debugging."
      false
  end
end


# Tests if the given TeX code compiles using the same header as used
# in results.pdf. Returns either true or false.
def test_tex_code(content)
  I18n.load_path += Dir.glob(File.join(Rails.root, '/config/locales/*.yml'))
  def t(t); I18n.t(t); end

  evalname = "Blame someone for bad LaTeX"
  head = ERB.new(RT.load_tex("preamble")).result(binding)
  foot = "\n\\end{document}"

  stat = -1
  d = Dir.mktmpdir("blame", Seee::Config.file_paths[:cache_tmp_dir])
  begin
    File.open(File.join(d, "blame.tex"), 'w') do |f|
      f.write(head)
      f.write(content)
      f.write(foot)
    end
    `cd "#{d}" && #{Seee::Config.commands[:pdflatex_fast]} blame.tex 2>&1`
    stat = $?.exitstatus
  ensure
    FileUtils.rm_r d
  end

  (stat == 0)
end
