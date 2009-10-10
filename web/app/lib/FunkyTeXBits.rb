#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

module FunkyTeXBits
  def TeXKopf(evalname, c_courses = 0, c_profs = 0, c_tutors = 0, c_forms = 0, single = nil)
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
    b << "\\usepackage{lmodern}\n"
    b << "\\usepackage{graphicx}\n"
    b << "\\usepackage[pdftex,%\n"
    b << "  pdftitle={Lehrevaluation #{evalname}},%\n"
    b << "  pdfauthor={Fachschaft MathPhys, Universität Heidelberg},%\n"
    b << "  pdfborder=0 0 1, \n bookmarks=true,\n pdftoolbar=true,\n pdfmenubar=true,\n colorlinks=true,\n	linkcolor=black,\n citecolor=black,\n filecolor=black,\n urlcolor=black]{hyperref}\n\n"
    b << "\\author{Universität Heidelberg\\\\Fachschaft MathPhys}\n"
    b << "\\renewcommand{\\labelitemi}{-}\n"
  
    if single.nil?
      b << "\\newcommand{\\profkopf}[2]{\\section*{Fragen zur Vorlesung (DozentIn: #1, #2 Bögen)}}\n"
      b << "\\newcommand{\\kurskopf}[3]{\\clearpage\n\\chapter{#1 bei #2}\nAbgegebene Fragebögen: #3}\n"
      b << "\\newcommand{\\fragenzurvorlesung}{\\section*{Fragen zur Vorlesung}}\n"
      b << "\\newcommand{\\fragenzudenuebungen}{\\section*{Fragen zum Übungsbetrieb}}\n"
      b << "\\newcommand{\\zusammenfassung}{\\paragraph{Zusammenfassung}}\n"
      b << "\\title{Lehrevaluation\\\\#{evalname}}\n"
      b << "\\date{\\today}\n"
    else
      b << "\\newcommand{\\profkopf}[2]{\\section{Fragen zur Vorlesung (DozentIn: #1, #2 Bögen)}}\n"
      b << "\\newcommand{\\kurskopf}[3]{\\section{Erhebungsgrundlage}\nAbgegebene Fragebögen: #3}\n"
      b << "\\newcommand{\\fragenzurvorlesung}{\\section{Fragen zur Vorlesung}}\n"
      b << "\\newcommand{\\fragenzudenuebungen}{\\section{Fragen zum Übungsbetrieb}}\n"
      b << "\\newcommand{\\zusammenfassung}{\\section{Zusammenfassung}}\n"
      b << "\\title{\\Large{Ergebnis der Evaluation}\\\\\\huge{#{evalname}}\\\\\\vspace{0.1cm}\\large{($dozent)}\\vspace{1.2cm}}\n"
      b << "\\date{\\today}"
    end
    
    b << "\\begin{document}\n\n"

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
      b << "  #{c_courses} & Vorlesungen \\\\\n" +
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
  
  def TeXFuss(single = nil)
    b = ''
    
    if single.nil?
      b << '\chapter'
    else
      b << "\\pagebreak\n"
      b << "\\section"
    end
    
    b << "{Die Fragebögen}\n"
    b << "\\includegraphics[height=.85\\textheight]{musterbogen1.pdf}\n\n"
    b << "\\begin{figure}\n"
    b << "\\includegraphics[height=.85\\textheight]{musterbogen2.pdf}\n\\end{figure}"
    b << "\n\\end{document}\n"
 
    return b
  end
end
