#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

module FunkyTeXBits
  def spellcheck(code)
    hunspell = Seee::Config.application_paths[:hunspell]

    # check if hunspell is installed
    `#{hunspell} --version`
    unless $?.to_i == 0
      logger.warn "Hunspell does not seem to be installed. Skipping spellcheck."
      return code
    end

    # write code to tempfile
    require 'digest'
    name = Digest::SHA256.hexdigest(code)
    path = "/tmp/seee_spellcheck_#{name}"
    File.open("#{path}", 'w') {|f| f.write(code) }

    # spell check!
    words = `#{Seee::Config.commands[:hunspell]} -l -t #{path}`.split("\n")
    File.delete(path)

    unless $?.to_i == 0
      logger.warn "Hunspell failed for some reason. Exit code: #{$?}"
      logger.warn "Hunspell: #{Seee::Config.commands[:hunspell]}"
      logger.warn "Path was: #{path}"
      logger.warn "Whole command: #{Seee::Config.commands[:hunspell]} -l -t #{path}"
      logger.warn "Code was: #{code}"
      logger.warn "Hunspell output: #{words.join("\n")}"
      return code
    end

    return code if words.empty?

    # highlight misspelled words
    w = words.join("|")
    r1 = Regexp.new(/.*\b(#{w})\b.*/)
    r2 = Regexp.new(/\b(#{w})\b/)
    blockers = Regexp.new(/\\pgf|\\spellingerror|\\begin{pgfpicture/)
    code.gsub!(r1) do |s|
      s.match(blockers).nil? ? s.gsub(r2, '\\spellingerror{\1}') : s
    end

    code
  end

  def texpreview(code)
    return false, ["(no content)"], "", "" if code.nil? || code.strip.empty?

    require 'lib/RandomUtils.rb'
    require 'digest'
    name = Digest::SHA256.hexdigest(code)
    path = "/tmp/seee_preview_#{name}"

    # will be overwritten on (re-)generation
    failed = false
    exitcodes = ['(cached image)']
    error = ""

    # see if it's cached, otherwise regenerate
    unless File.exists?("#{path}.base64")
      head = praeambel("Blaming Someone For Bad LaTeX")
      head << "\\pagestyle{empty}"
      foot = "\\end{document}"

      File.open(path + ".tex", 'w') do |f|
        f.write(head + spellcheck(code) + foot)
      end

      error = `cd /tmp/ && #{Seee::Config.commands[:pdflatex_real]} #{path}.tex 2>&1`
      ex = $?.to_i + (File.exists?("#{path}.pdf") ? 0 : 1)
      error << spellcheck(code)
      exitcodes = []
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

      # convert to base64 and store to disk
      if File.exists?("#{path}.png")
        require 'base64'
        data = File.open("#{path}.png", 'rb') { |f| f.read }
        base64 = Base64.encode64(data)
        File.open("#{path}.base64", 'w') {|f| f.write(base64) }
      end
    end

    # only read from disk if the image has not been created above
    if base64.nil? && File.exists?("#{path}.base64")
        base64 = File.open("#{path}.base64", 'rb') { |f| f.read }
    end

    # cleanup temp files
    [".tex", ".pdf", ".out", ".log", "-crop.pdf", ".aux", ".png", \
        "-0.png", "-1.png", "-2.png", "-3.png"].each { |c| `rm -f "#{path}#{c}"` }

    return failed, exitcodes, error.gsub("\n", "<br/>"), base64
  end

  def praeambel(evalname, single = nil)
    b = ''
    if single.nil?
      b << "\\documentclass[pagesize,halfparskip-,headsepline," +
        "cleardoubleempty]{scrbook}\n"
    else
       b << "\\documentclass[pagesize,halfparskip-]{scrartcl}\n"
    end

    b << "\\areaset[1cm]{17cm}{26cm}\n"
    b << "\\usepackage[utf8]{inputenc}\n"
    b << "\\usepackage[T1]{fontenc}\n"
    b << "\\usepackage{ngerman}\n"
    b << "\\usepackage{pgf} % drawings with jpgjdraw\n"
    b << "\\usepackage{lmodern}\n"
    b << "\\usepackage{longtable}\n"
    b << "\\usepackage{marvosym}\n"
    b << "\\usepackage[protrusion=true,expansion]{microtype}\n"
    b << "\\usepackage{graphicx}\n"
    b << "\\usepackage{color}\n"
    b << "\\usepackage[pdftex,%\n"
    b << "  pdftitle={Lehrevaluation #{evalname}},%\n"
    b << "  pdfauthor={Fachschaft MathPhys, Universität Heidelberg},%\n"
    b << "  pdfborder=0 0 1, \n bookmarks=true,\n pdftoolbar=true,\n pdfmenubar=true,\n colorlinks=true,\n  linkcolor=black,\n citecolor=black,\n filecolor=black,\n urlcolor=black]{hyperref}\n\n"
    b << "\\author{Universität Heidelberg\\\\Fachschaft MathPhys}\n"
    b << "\\renewcommand{\\labelitemi}{-}\n"
    b << "\\newcommand{\\spellingerror}[1]{\\textcolor{red}{#1}}\n"

    if single.nil?
      b << "\\newcommand{\\profkopf}[1]{\\section*{#1}}\n"
      b << "\\newcommand{\\kurskopf}[6]{\\clearpage\n\\pdfdest name{#4} xyz%\n\\chapter{#1 #5 #2}\n#6: #3}\n"
      b << "\\newcommand{\\fragenzudenuebungen}[1]{\\section*{#1}}\n"
      b << "\\newcommand{\\uebersichtuebungsgruppen}[1]{\\section*{#1}}\n"
      b << "\\newcommand{\\commentsprof}[1]{\\textbf{#1}}\n"
      b << "\\newcommand{\\commentstutor}[1]{\\textbf{#1}}\n"
      b << "\\title{Lehrevaluation\\\\#{evalname}}\n"
      b << "\\date{\\today}\n"
    else
      b << "\\newcommand{\\profkopf}[1]{\\section{#1}}\n"
      b << "\\newcommand{\\kurskopf}[6]{\\clearpage\n\\pdfdest name{#4} xyz%\n\\chapter{#1 #5 #2}\n#6: #3}\n"
      b << "\\newcommand{\\fragenzudenuebungen}[1]{\\section{#1}}\n"
      b << "\\newcommand{\\uebersichtuebungsgruppen}[1]{\\section{#1}}\n"
      b << "\\newcommand{\\zusammenfassung}[1]{\\section{#1}}\n"
      b << "\\title{\\Large{Ergebnis der Evaluation}\\\\\\huge{#{evalname}}\\\\\\vspace{0.1cm}\\large{($dozent)}\\vspace{1.2cm}}\n"
      b << "\\date{\\today}"
    end

    b << "\\begin{document}\n\n"
  end

  def TeXKopf(evalname, c_courses = 0, c_profs = 0, c_tutors = 0, c_forms = 0, single = nil)
    b = ''

    # FIXME: Need to encapsulate form stuff. I.e. if it's a seminar,
    # a lecture and if it's German or English. The class should
    # automatically provide appropriate strings for all language
    # specifics
    b << praeambel(evalname, single)

    if single.nil?
      b << "\\begin{titlepage}\n"
      b << "\\null\\vskip 2.5cm\n"
      b << "\\begin{center}\n"
      b << "{\\parskip0pt\n"
      b << "{\\sectfont\\Huge \\makeatletter\\\@title\\makeatother \\par}\n"
      b << "\\vspace{2em}\n"
      b << "{\\usekomafont{sectioning}\\mdseries\\LARGE\n"
      b << "Ergebnisse der Vorlesungsumfrage\\par}\n"
      b << "\\vfill\n"
      b << "{\\Large \\makeatletter\\\@author\\makeatother \\par}\n"
      b << "\\vspace{4em}\n"
      b << "{\\Large \\makeatletter\\\@date\\makeatother \\par}\n"
      b << "\\vfill\n"
      b << "}\n"
      b << "\\end{center}\n"
      b << "\\clearpage\\thispagestyle{empty}\\null\\vfill\n"
      b << "\\noindent\\begin{minipage}[b]{\\textwidth}\n"
      b << "\\textbf{Umfang dieser Evaluation:}\\par\\medskip\n"
      b << "\\begin{tabular}[b]{rl}\\hline\n"
      b << "  #{c_courses} & Veranstaltungen \\\\\n" +
        "  #{c_profs} & Dozenten \\\\\n" +
        "  #{c_tutors} & Übungsgruppen\\\\\n" +
        "  #{c_forms} & ausgewertete Fragebögen\\\\\\hline"
      b << "\\end{tabular}\\hfill\n"
#    b << "{\\footnotesize\\texttt{%\n"
#    b << "  Auswertung: SVN-Revision $SvnRevision ($SvnDate $SvnTime)}}\n"
      b << "\\end{minipage}\n"
      b << "\\end{titlepage}\n\n"
      b << "\\makeatletter\n"
      b << "\\renewcommand{\\l\@section}{\\\@dottedtocline{1}{1.5em}{2.8em}}\n"
      b << "\\makeatother\n"
      b << "\\tableofcontents\n\n"
    else
      b << "\\maketitle\n\\tableofcontents\n"
    end

    return b
  end

  def TeXVorwort(facultylong, semestershort, single = nil)
    b = ''

    if single.nil?
      b << '\chapter'
    else
      b << "\\pagebreak\n"
      b << "\\section"
    end
    b << "{Vorwort}"

    semesterlong = semestershort.gsub("WS", "Wintersemester").gsub("SS", "Sommersemester")
    b << "\\newcommand{\\facultylong}{#{facultylong}}\n"
    b << "\\newcommand{\\semesterlong}{#{semesterlong}}\n"
    b << "\\input{" + File.join(Rails.root, "../tex/vorwort.tex") + "}\n"
    b
  end

  def TeXFuss(single = nil)
    b = ''

    if single.nil?
      b << '\chapter'
    else
      b << "\\pagebreak\n"
      b << "\\section"
    end

    path = File.join(Rails.root, "../tmp/sample_sheets/sample_")
    b << "{Die Fragebögen}\n"

    $curSem.forms.each do |f|
      f.languages.each do |l|
        b << "\\subsection*{#{f.name}}"
        1.upto(f.pages.count) do |i|
          b << "\\fbox{\\includegraphics[height=.85\\textheight,page=#{i}]{#{path}#{f.id}_#{l.to_s}.pdf}}\n"
          b << "\\clearpage"
        end
      end
    end
    b << "\n\\end{document}\n"

    return b
  end
end
