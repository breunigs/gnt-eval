\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{eval}[2009/09/22 Evaluationsbögen]

\LoadClass[9pt,twoside]{scrartcl} 

\DeclareOption*{%
\PassOptionsToClass{\CurrentOption}{scrartcl}%
}
\ProcessOptions\relax 

\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage{amssymb} 
\RequirePackage{array} 
\RequirePackage{babel}
\RequirePackage{booktabs} 
\RequirePackage{boxedminipage}
\RequirePackage{color}
\RequirePackage{fancyhdr}
\RequirePackage{geometry} 
\RequirePackage{ifthen}
\RequirePackage{multirow} 
\RequirePackage{graphicx} 
\RequirePackage{xspace}
\RequirePackage{microtype}
\RequirePackage{tokeniz0r}
\RequirePackage{tgheros}
\renewcommand{\rmdefault}{\sfdefault}

\date{}
\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0pt}
%\fancyfoot[OR]{\vspace{-1.3cm}\hspace{5cm}bitte wenden}
%\pagestyle{empty}

\renewcommand{\baselinestretch}{1}
\setlength\tabcolsep{0pt}
\geometry{left=9mm,right=9mm, top=1cm, bottom=1cm}
\setlength\parindent{0pt} 

\newwrite\posout
\openout\posout\jobname.posout

\def\Source{}

\def\SaveMyYPos{
  \pdfsavepos
	\write\posout{uuu x: \number\pdflastxpos}
	\write\posout{uuu y: \number\pdflastypos}
}

\def\stefanistdoof{
	\pdfsavepos
		\write\posout{u ylast: \number\pdflastypos}
}

\def\was{\textbf{Titel:} \vor \hfill\textbf{Dozent:} \doz \hfill\textbf{Semester:} \sem \vspace{0.3em}}

\def\np{\newpage
\write\posout{- !ruby/object:Page}
\write\posout{u questions:}
}

\def\mm[#1][#2]{\write\posout{uu- !ruby/object:Box}
 \write\posout{uuu choice: "#1"}
 \write\posout{uuu height: 0}
 \write\posout{uuu text: "#2"}
 \write\posout{uuu width: 0}
}

\def\mmm[#1][#2]{ \write\posout{uuu choice: "#1"}
 \write\posout{uuu height: 0}
 \write\posout{uuu text: "#2"}
 \write\posout{uuu width: 0}
 \vspace{-0.3cm}
}

\def\bx{\huge{$\Box$}\normalsize\SaveMyYPos}
\def\bxs[#1][#2]{\vspace{-0.8em}\mm[#1][#2]\hspace{0.5em}\huge{$\Box$}\normalsize\SaveMyYPos}
\def\bxss[#1][#2]{\vspace{-0.8em}\mm[#1][#2]\hspace{-0.43cm}\huge{$\Box$}\normalsize\SaveMyYPos}

\newcommand{\Typ}[1]{\def\typ{#1}}
\newcommand{\dozent}[1]{\def\doz{#1}}
\newcommand{\vorlesung}[1]{\def\vor{#1}}
\newcommand{\semester}[1]{\def\sem{#1}}
\newcommand{\tutoren}[1]{\def\tut{#1}}

\def\vorlesungsfragen{\input{/home/jasper/texlive/fragen/fragen}}
\def\seminarfragen{\input{/home/jasper/sumpf/eval/bogen/TeX-Bogen/fragen_seminar}}
\def\struktur{\input{/home/jasper/Uni/mathphys/eval/fragen_struktur3}}

\def\blu[#1]{\write\posout{u - !ruby/object:Question}
    \write\posout{uu active: true}
    \write\posout{uu failchoice: -1}
    \write\posout{uu nochoice: }
    \write\posout{uu qtext: "#1"}
    %\write\posout{uu save_as: ""}
    \write\posout{uu type: square}
    \write\posout{uu db_column: }
    \whiledo{\not\equal{\Source}{}}
	{
    		\GetTokens{TokenOne}{TokenTwo}{\Source}
		\expandafter\write\expandafter\posout\expandafter{\TokenOne}
    		\let\Source\TokenTwo
	}
    \write\posout{uu boxes:}
}
\def\bluu[#1][#2]{\write\posout{u - !ruby/object:Question}
    \write\posout{uu active: true}
    \write\posout{uu failchoice: -1}
    \write\posout{uu nochoice: }
    \write\posout{uu qtext: "#1"}
    \write\posout{uu save_as: ""}
    \write\posout{uu type: square}
    \write\posout{uu db_column: #2}
    \write\posout{uu boxes:}
}

\definecolor{grau}{rgb}{.85,.85,.85}

\newcommand{\sect}[1]{
\fcolorbox{black}{grau}{
\begin{minipage}{18.7cm}
\centering\Large{#1}
\end{minipage}
}
\vspace{0.13cm}
}

\newcommand{\secte}{
\vspace{-1.2em}\rule{19cm}{1.5pt}\vspace{0.5em}
}

\newcommand{\kommentar}[4]{\write\posout{u - !ruby/object:Question}
	\write\posout{uu active: true}
	\write\posout{uu nochoice: }
	\write\posout{uu choice: }
	\write\posout{uu qtext: "#1"}
    	\write\posout{uu save_as: "#3"}
    	\write\posout{uu type: text}
    	\write\posout{uu db_column: "#2"}
	#1\write\posout{uu boxes:}\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: start}\write\posout{uuu height: 743249}\SaveMyYPos\hfill\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: end}\SaveMyYPos\\\write\posout{uu- !ruby/object:Box}\SaveMyYPos\vspace{1.5cm}
	\write\posout{uuu height: #4}
 	\write\posout{uuu width: 39020584}
}

\newcommand{\qvi}[8]{
%\def\Source{#8,}
\bluu[#1][#8]
\begin{minipage}{15cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.5cm}>{\centering}p{1.5cm}>{\centering}p{1.5cm}>{\centering}p{1.5cm}>{\centering}p{1.5cm}p{0cm}}
\multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \bxs[4][#5] & \bxs[5][#6] & \bxs[6][#7] &\\
   & \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \small#7 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qv}[7]{
\bluu[#1][#7]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}>{\centering}p{2cm}p{0cm}}
\multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \bxs[4][#5] & \bxs[5][#6] &\\
   &  \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qvs}[7]{
\bluu[#1][#7]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}|>{\centering}p{2cm}p{0cm}}
\multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \bxs[4][#5] & \bxs[5][#6] &\\
   &  \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qvm}[7]{
\def\Source{uu - #7a,uu - #7b,uu - #7c,uu - #7d,uu - #7e,}
\blu[#1]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}>{\centering}p{2cm}p{0cm}}
\multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \bxs[4][#5] & \bxs[5][#6] &\\
   &  \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qvl}[7]{
\def\Source{#7,}
\blu[#1]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}>{\centering}p{2cm}p{0cm}}
\multirow{3}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \bxs[4][#5] & \bxs[5][#6] &\\
   &  \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \\
& & & & &\\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}
 
\newcommand{\qiv}[6]{
\bluu[#1][#6]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.75cm}>{\centering}p{2.75cm}>{\centering}p{2cm}p{0cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \bxs[4][#5] & \\
   &  \small#2 & \small#3 & \small#4 & \small#5 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qivm}[6]{
\def\Source{uu - #6a,uu - #6b,uu - #6c,uu - #6d,}
\blu[#1]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.75cm}>{\centering}p{2.75cm}>{\centering}p{2cm}p{0cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \bxs[4][#5] & \\
   & \small#2 & \small#3 & \small#4 & \small#5 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qiii}[5]{
\bluu[#1][#5]
\begin{minipage}{15cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}p{1cm}>{\centering}p{3.5cm}p{1cm}>{\centering}p{2cm}p{0cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[1][#2] & & \bxs[2][#3] & & \bxs[3][#4] &  \\
   & \small#2 & & \small#3 &  & \small#4 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qiiim}[5]{
\def\Source{uu - #5a,uu - #5b,uu - #5c,}
\blu[#1]
\begin{minipage}{15cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{5.5cm}>{\centering}p{2cm}p{0.1cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] & \bxs[3][#4] &  \\
   & \small#2 & \small#3 & \small#4 & \\
\bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qii}[4]{
\bluu[#1][#4]
\begin{minipage}{15cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.85cm}p{4.65cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] &  \\
   & \small#2 & \small#3 & \\
 \bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qiim}[4]{
\def\Source{uu- #4a,uu- #4b,}
\blu[#1]
\begin{minipage}{15cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.85cm}p{4.65cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[#1][#2] & \bxs[#2][#3] &  \\
   & \small#2 & \small#3 & \\
 \bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\kopf}[1]{
\write\posout{--- !ruby/object:Form}
\write\posout{db_table: evaldaten_ss09}
\write\posout{pages: }
\write\posout{- !ruby/object:Page }
\write\posout{u questions: }

  \ifthenelse{\equal{#1}{1}}{\Huge{Umfrage zur Qualität der Lehre}\normalsize}{\Huge{Lehrevaluation -- Seminare}\normalsize}\hfill\includegraphics[width=3cm,height=1.5cm]{barcode.pdf}\\ \vspace{0.1cm}

Diese Evaluation wird von der Studienkommission in Zusammenarbeit mit der Fachschaft MathPhys durchgeführt. Dieser Bogen soll helfen, die Lehre zu verbessern bzw. Lehrveranstaltungen guter Qualität zu erhalten. Auch in eurem Interesse bitten wir euch, den Bogen sorgfältig und deutlich lesbar auszufüllen.\vspace{0.3cm}

\was
\\[0.5em]
  \ifthenelse{\equal{#1}{1}}{
\bluu[Übungsgruppe][v1]
\hspace{-0.9cm}\textbf{Übungsgruppe:}\\[0.2em]
\begin{tabular}{@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}}
\tut
 \end{tabular}
\\[1em] }{}
\bluu[Studienziel][v2]
\hspace{-0.9cm}\textbf{Studienziel:} \\[0.3em]
\bxss[1][Diplom] Diplom \hfill \bxs[2][Lehramt] Lehramt \hfill \bxs[3][Bachelor] Bachelor \hfill \bxs[4][Master] Master \hfill \bxs[5][Promotion] Promotion \hfill \bxs[6][Sonstiges] Sonstiges \vspace{1.6cm} \\
\bluu[Hauptfach][v3]
\hspace{-0.9cm}\textbf{Hauptfach:} \\[0.01em]
\bxss[1][Mathe] Mathe \hspace{0.8cm} \bxs[2][Physik] Physik \hspace{0.9375cm} \bxs[3][Informatik] Informatik \hfill \bxs[5][Sonstiges] Sonstiges \vspace{1cm} \\
\bluu[Fachsemester][v4]
\hspace{-0.9cm}\textbf{Fachsemester:} \\[0.4em]
\bxss[1][1]\hspace{-0.5em}1\hfill \bxss[2][2]\hspace{-0.5em}2\hfill \bxss[3][3]\hspace{-0.5em}3 \hfill \bxss[4][4]\hspace{-0.5em}4 \hfill \bxss[5][5]\hspace{-0.5em}5 \hfill \bxss[6][6]\hspace{-0.5em}6 \hfill \bxss[7][7]\hspace{-0.5em}7 \hfill \bxss[8][8]\hspace{-0.5em}8 \hfill \bxss[9][9]\hspace{-0.5em}9 \hfill \bxss[10][10]\hspace{-0.5em}10 \hfill \bxss[11][11]\hspace{-0.5em}11 \hfill \bxss[12][12]\hspace{-0.5em}12 \hfill \bxss[13][13]\hspace{-0.5em}13 \hfill \bxss[14][14]\hspace{-0.5em}14 \hfill \bxss[15][15]\hspace{-0.5em}15 \hfill \bxss[16][>15]\hspace{-0.5em}>15 \\
\vspace{4cm}
}
