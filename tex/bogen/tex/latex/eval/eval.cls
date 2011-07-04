\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{eval}[2011/05/12 Evaluationsbögen]

\LoadClass[twoside,8pt]{scrartcl}

\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage{amssymb}
\RequirePackage{array}
\RequirePackage{babel}
\RequirePackage{booktabs}
\RequirePackage{bophook}
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
\RequirePackage{xparse}
\renewcommand{\rmdefault}{\sfdefault}

\renewcommand{\TruncateMarker}{\textasciitilde}

\AtBeginPage{
}

\DeclareOption{kanten}{\AtBeginPage
{\put(10, -15){\rule{1cm}{1pt}}
\put(10, -43){\rule{1pt}{1cm}}
\put(10, -830){\rule{1cm}{1pt}}
\put(10, -830){\rule{1pt}{1cm}}
\put(559, -15){\rule{1cm}{1pt}}
\put(586.5, -43){\rule{1pt}{1cm}}
\put(559, -830){\rule{1cm}{1pt}}
\put(586.5, -830){\rule{1pt}{1cm}}
\write\posout{- !ruby/object:Page}
\write\posout{u questions:}
}}


\DeclareOption*{%
\PassOptionsToClass{\CurrentOption}{scrartcl}%
}
\ProcessOptions\relax

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

\def\tutorbox[#1][#2]{%
	\write\posout{uuu choice: "#1"}
	\write\posout{uuu height: 0}
	\write\posout{uuu text: "#2"}
	\write\posout{uuu width: 0}
	\vspace{-0.3cm}
	\truncate{3cm}{#2}
}

\def\bx{\huge{$\Box$}\normalsize\SaveMyYPos}

\def\bxs[#1][#2]{%
	\vspace{-0.8em}
	\write\posout{uu- !ruby/object:Box}
	\write\posout{uuu choice: "#1"}
	\write\posout{uuu height: 0}
	\write\posout{uuu text: "#2"}
	\write\posout{uuu width: 0}
	\hspace{0.5em}
	\huge{$\Box$}\normalsize\SaveMyYPos}

\def\bxss[#1][#2]{%
	\vspace{-0.8em}
  	\write\posout{uu- !ruby/object:Box}
	 \write\posout{uuu choice: "#1"}
	 \write\posout{uuu height: 0}
	 \write\posout{uuu text: "#2"}
	 \write\posout{uuu width: 0}
	\hspace{-0.43cm}
	\huge{$\Box$}\normalsize\SaveMyYPos}

\newcommand{\dozent}[1]{\def\doz{#1}}
\newcommand{\vorlesung}[1]{\def\vor{#1}}
\newcommand{\semester}[1]{\def\sem{#1}}
\newcommand{\dbtable}[1]{\def\dbt{#1}}
\newcommand{\tutoren}[1]{\def\tut{#1}}

\def\SaveMultiInfo[#1]{\write\posout{u - !ruby/object:Question}
    \write\posout{uu qtext: "#1"}
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
\def\SaveNormalInfo[#1][#2]{\write\posout{u - !ruby/object:Question}
    \write\posout{uu qtext: "#1"}
    \write\posout{uu type: square}
    \write\posout{uu db_column: #2}
    \write\posout{uu boxes:}
}

\definecolor{gray}{rgb}{.88,.88,.88}

\newcommand{\sect}[1]{
\fcolorbox{black}{gray}{
\begin{minipage}{18.8cm}
\centering\Large{#1}
\end{minipage}
}
\vspace{0.13cm}
}

\newcommand{\secte}{
\vspace{-1.2em}\rule{19cm}{1.5pt}\vspace{0.5em}
}

% used at the end of the page to mark the end of a comment field
\newcommand{\separator}[1]{
  \vspace{-1.2em}\rule{19.2cm}{#1}
}

\newcommand{\comment}[3]{\write\posout{u - !ruby/object:Question}
	\write\posout{uu choice: }
	\write\posout{uu qtext: "#1"}
    	\write\posout{uu save_as: "#3"}
    	\write\posout{uu type: text}
    	\write\posout{uu db_column: "#2"}
	#1\hspace*{0.5cm}\write\posout{uu boxes:}\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: start}\write\posout{uuu height: 650000}\SaveMyYPos\hfill\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: end}\SaveMyYPos\\\write\posout{uu- !ruby/object:Box}\SaveMyYPos\vspace*{3200000sp}
	\write\posout{uuu height: 3200000}
 	\write\posout{uuu width: 39020584}
}


\NewDocumentCommand\quest{d<> m m o o o o o o}{%
%This is to test if we have a Multiple Choice Question
\IfNoValueTF{#1}{%
		\SaveNormalInfo[#3][#2]
}{
		\IfNoValueTF{#9}{
		\IfNoValueTF{#8}{
		\IfNoValueTF{#7}{
		\IfNoValueTF{#6}{
		\IfNoValueTF{#5}{%1
		    \def\Source{uu - #2a,}
		}{%2
		    \def\Source{uu - #2a,uu - #2b,}
		}}{%3
		    \def\Source{uu - #2a,uu - #2b,uu - #2c,}
		}}{%4
		    \def\Source{uu - #2a,uu - #2b,uu - #2c,uu - #2d,}
		}}{%5
		    \def\Source{uu - #2a,uu - #2b,uu - #2c,uu - #2d,uu - #2e,}
		}}{%6
		    \def\Source{uu - #2a,uu - #2b,uu - #2c,uu - #2d,uu - #2e,uu - #2f,}
		}
		\SaveMultiInfo[#3]
}
%Print the question, depending on how many answers are given, for this I will burn in hell!
		\begin{minipage}{17cm}
		\IfNoValueTF{#9}{
		 \IfNoValueTF{#8}{
    		  \IfNoValueTF{#7}{
		   \IfNoValueTF{#6}{
		    \IfNoValueTF{#5}{
 			\Huge{Wir sind doch nicht in der DDR hier!}\\
 			}{%2
			 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.85cm}p{4.65cm}p{0.2cm}}
			 \multirow{2}{9.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] &  \\
			 & \small#4 & \small#5 & & \\
			\bottomrule
			\end{tabular}
}
			}{%3
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}p{1cm}>{\centering}p{3.5cm}p{1cm}>{\centering}p{2cm}p{0.2cm}}
 \multirow{2}{9.4cm}{#3} & \bxs[1][#4] & & \bxs[2][#5] & & \bxs[3][#6] &  \\
   & \small#4 & & \small#5 &  & \small#6 & \\
\bottomrule
 \end{tabular}
}
			}{%4
			 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{2.75cm}>{\centering}p{2.75cm}>{\centering}p{2cm}p{0.2cm}}
			 \multirow{2}{9.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] & \bxs[3][#6] &  \bxs[4][#7] & \\
   &  \small#4 & \small#5 & \small#6 & \small#7 & \\
\bottomrule
 \end{tabular}
}
			}{%5
 \begin{tabular}{p{10cm}>{\centering}p{1.5cm}>{\centering}p{1.8cm}>{\centering}p{1.9cm}>{\centering}p{1.8cm}>{\centering}p{2cm}p{0.2cm}}
\multirow{2}{9.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] & \bxs[3][#6] &  \bxs[4][#7] & \bxs[5][#8] &\\
   &  \small#4 & \small#5 & \small#6 & \small#7 & \small#8 & \\
\bottomrule
 \end{tabular}
}
			}{%6
 \begin{tabular}{p{10cm}>{\centering}p{1.48cm}>{\centering}p{1.45cm}>{\centering}p{1.46cm}>{\centering}p{1.47cm}>{\centering}p{1.45cm}>{\centering}p{1.4cm}p{0.49cm}}
\multirow{2}{9.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] & \bxs[3][#6] &  \bxs[4][#7] & \bxs[5][#8] & \bxs[6][#9] &\\
   & \small#4 & \small#5 & \small#6 & \small#7 & \small#8 & \small#9 & \\
\bottomrule
 \end{tabular}
}
		\end{minipage}
		\vspace{0.2em}
}

\newcommand{\head}[2]{
  \write\posout{--- !ruby/object:AbstractForm}
  \write\posout{db_table: \dbt}
  \write\posout{pages: }
  \write\posout{- !ruby/object:Page }
  \write\posout{u questions: }
  \vspace*{-0.4cm}
  \Huge{#1}\normalsize
  % the raisebox makes the headline and barcode to have the same baseline
  \hfill\raisebox{-2.55ex}{\includegraphics[width=3cm,height=1.5cm]{barcode#2.pdf}}\\
}

\newcommand{\dataline}[3]{
  \textbf{#1:} \vor \hfill\textbf{#2:} \doz \hfill\textbf{#3:} \sem \\[0.2em]
}

\newcommand{\printspecialheader}[1]{
  \makebox[1.0\textwidth][l]{\hspace*{0.0cm}\textbf{#1:}}\vspace{0.1cm}
}

\newcommand{\boxfixed}[2]{
  \bxss[#1][#2]
  \makebox[2.31cm][l]{\truncate{2.31cm}{\raisebox{0.4ex}{#2}}}
  \makebox[0.05cm]{}
}

\newcommand{\boxfixedempty}{
  \phantom{\bxss[][]}
  \makebox[2.31cm][l]{}
  \makebox[0.05cm]{}
}

\newcommand{\boxvariable}[2]{
  \bxss[#1][#2]\raisebox{0.4ex}{#2}
}

\newcommand{\printtutors}[1]{
  \ifthenelse{\isundefined{\tut}}{}{
    \SaveNormalInfo[#1][tutnum]%
    \printspecialheader{#1}
    \makebox[1.0\textwidth][l]{
    \hspace*{-0.1cm}\begin{tabular}{@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\write\posout{uu- !ruby/object:Box}\bx}p{3.2cm}}
    \tut
    \end{tabular}
    }
    \vspace{0.1cm}
  }
}

\newcommand{\backpagecomment}[1]{
  \newpage
  \mbox{}
  \write\posout{u - !ruby/object:Question}
  \write\posout{uu type: text_wholepage}
  \write\posout{uu db_column: "#1"}
  \write\posout{uu save_as: "vcomment"}
}
