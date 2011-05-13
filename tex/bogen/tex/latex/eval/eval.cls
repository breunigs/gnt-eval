\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{eval}[2011/05/12 Evaluationsbögen]

\LoadClass[twoside,8pt]{scrartcl}

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
\RequirePackage[breakall]{truncate}
\renewcommand{\rmdefault}{\sfdefault}

\renewcommand{\TruncateMarker}{\textasciitilde}


\date{}
\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0pt}

\renewcommand{\baselinestretch}{1}
\setlength\tabcolsep{0pt}
\geometry{left=9mm,right=9mm, top=0.8cm, bottom=0.8cm}
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
 \truncate{3cm}{#2}
}

\def\bx{\huge{$\Box$}\normalsize\SaveMyYPos}
\def\bxs[#1][#2]{\vspace{-0.8em}\mm[#1][#2]\hspace{0.5em}\huge{$\Box$}\normalsize\SaveMyYPos}
\def\bxss[#1][#2]{\vspace{-0.8em}\mm[#1][#2]\hspace{-0.43cm}\huge{$\Box$}\normalsize\SaveMyYPos}
%\def\bxs[#1][#2]{\vspace{-0.8em}\mm[#1][#2]\hspace{0.5em}{$\bigcirc$}\normalsize\SaveMyYPos}

\newcommand{\Typ}[1]{\def\typ{#1}}
\newcommand{\dozent}[1]{\def\doz{#1}}
\newcommand{\vorlesung}[1]{\def\vor{#1}}
\newcommand{\semester}[1]{\def\sem{#1}}
\newcommand{\dbtable}[1]{\def\dbt{#1}}
\newcommand{\tutoren}[1]{\def\tut{#1}}

\def\blu[#1]{\write\posout{u - !ruby/object:Question}
    \write\posout{uu active: true}
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
    \write\posout{uu qtext: "#1"}
    \write\posout{uu save_as: ""}
    \write\posout{uu type: square}
    \write\posout{uu db_column: #2}
    \write\posout{uu boxes:}
}

\definecolor{grau}{rgb}{.88,.88,.88}

\newcommand{\sect}[1]{
\fcolorbox{black}{grau}{
\begin{minipage}{18.8cm}
\centering\Large{#1}
\end{minipage}
}
\vspace{0.13cm}
}

\newcommand{\secte}{
\vspace{-1.2em}\rule{19cm}{1.5pt}\vspace{0.5em}
}

\newcommand{\kommentar}[3]{\write\posout{u - !ruby/object:Question}
	\write\posout{uu active: true}
	\write\posout{uu choice: }
	\write\posout{uu qtext: "#1"}
    	\write\posout{uu save_as: "#3"}
    	\write\posout{uu type: text}
    	\write\posout{uu db_column: "#2"}
	#1\write\posout{uu boxes:}\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: start}\write\posout{uuu height: 743249}\SaveMyYPos\hfill\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: end}\SaveMyYPos\\\write\posout{uu- !ruby/object:Box}\SaveMyYPos\vspace{3300000sp}
	\write\posout{uuu height: 3300000}
 	\write\posout{uuu width: 39020584}
}

\newcommand{\comment}[4]{\write\posout{u - !ruby/object:Question}
	\write\posout{uu active: true}
	\write\posout{uu choice: }
	\write\posout{uu qtext: "#1"}
    	\write\posout{uu save_as: "#3"}
    	\write\posout{uu type: text}
    	\write\posout{uu db_column: "#2"}
	#1\write\posout{uu boxes:}\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: start}\write\posout{uuu height: 743249}\SaveMyYPos\hfill\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: end}\SaveMyYPos\\\write\posout{uu- !ruby/object:Box}\SaveMyYPos\vspace{1.2cm}
	\write\posout{uuu height: #4}
 	\write\posout{uuu width: 39020584}
}



\newcommand{\qvi}[8]{
%\def\Source{#8,}
\bluu[#1][#8]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.48cm}>{\centering}p{1.45cm}>{\centering}p{1.46cm}>{\centering}p{1.47cm}>{\centering}p{1.45cm}>{\centering}p{1.4cm}p{0.49cm}}
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
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}>{\centering}p{2cm}p{0.2cm}}
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
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}|>{\centering}p{2cm}p{0.2cm}}
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
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}>{\centering}p{2cm}p{0.2cm}}
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
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}>{\centering}p{2cm}p{0.2cm}}
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
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.75cm}>{\centering}p{2.75cm}>{\centering}p{2cm}p{0.2cm}}
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
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.75cm}>{\centering}p{2.75cm}>{\centering}p{2cm}p{0.2cm}}
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
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}p{1cm}>{\centering}p{3.5cm}p{1cm}>{\centering}p{2cm}p{0.2cm}}
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiih%%%%%%%%%%%%%%%%%%%%%%%%%%%

\newcommand{\ikkifthagn}{
\write\posout{- !ruby/object:Page}
\write\posout{u questions:}
\write\posout{u - !ruby/object:Question}
\write\posout{uu type: text_wholepage}
\write\posout{uu save_as: "-comment"}
}


\newcommand{\qii}[4]{
\bluu[#1][#4]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.85cm}p{4.65cm}p{0.2cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[1][#2] & \bxs[2][#3] &  \\
   & \small#2 & \small#3 & & \\
 \bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\qiim}[4]{
\def\Source{uu- #4a,uu- #4b,}
\blu[#1]
\begin{minipage}{17cm}
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.85cm}p{4.65cm}p{0.2cm}}
 \multirow{2}{9.4cm}{#1} & \bxs[#1][#2] & \bxs[#2][#3] &  \\
   & \small#2 & \small#3 & & \\
 \bottomrule
 \end{tabular}
\end{minipage}
\vspace{0.2em}
}

\newcommand{\head}[2]{
  \write\posout{--- !ruby/object:AbstractForm}
  \write\posout{db_table: \dbt}
  \write\posout{pages: }
  \write\posout{- !ruby/object:Page }
  \write\posout{u questions: }
  \Huge{#1}\normalsize
  \hfill\includegraphics[width=3cm,height=1.5cm]{barcode#2.pdf}\\
  \vspace{0.1cm}
}

\newcommand{\dataline}[3]{
  \textbf{#1:} \vor \hfill\textbf{#2:} \doz \hfill\textbf{#3:} \sem \\[0.2em]
}

\newcommand{\printtutors}[1]{
  \ifthenelse{\isundefined{\tut}}{}{
    \bluu[#1][tutnum]%
    \makebox[1.0\textwidth][l]{\hspace*{0.0cm}\textbf{#1:}}\vspace{0.05cm}
    \makebox[1.0\textwidth][l]{
    \hspace*{-0.105cm}\begin{tabular}{@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}}
    \tut
    \end{tabular}
    }
    \vspace{0.1cm}
  }
}

\newcommand{\separator}[1]{
  \vspace{-0.7em}\rule{19.2cm}{#1}
}
