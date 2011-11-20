\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{eval}[2011/05/12 Evaluationsbögen]

\LoadClass[twoside,8pt]{scrartcl}

\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage{amssymb}
\RequirePackage{array}
\RequirePackage{babel}
\RequirePackage{booktabs}
\RequirePackage{calc}
\RequirePackage{bophook}
\RequirePackage{color}
\RequirePackage{geometry}
\RequirePackage{ifthen}
\RequirePackage{multirow}
\RequirePackage{graphicx}
\RequirePackage{microtype}
\RequirePackage{tokeniz0r}
\RequirePackage{tgheros}
\RequirePackage[breakall]{truncate}
\RequirePackage{xparse}
\renewcommand{\rmdefault}{\sfdefault}

\renewcommand{\TruncateMarker}{\textasciitilde}

% backup hline command. hline will be disabled when a new section begins in order
% to avoid several rules. hlineback is used to restore hline functionality after
% each question.
\let\hlineback\hline

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% for-each-page stuff (e.g. headers, edges)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% default section headers are small headers
\newcommand{\sect}{\sectsmall}
\newcommand{\headerHeightForPut}{-33}
\newcommand{\headerHeight}{5.2mm}

% same options, but for large headers
\DeclareOption{large}{
  \renewcommand{\sect}{\sectlarge}
  \renewcommand{\headerHeightForPut}{-32.2}
  \renewcommand{\headerHeight}{5mm}
}

% add height of the header to each page margin, so repeated-headers can be placed on top of the
% page easily. The margin for the for the first page, which cannot have a repeated header, is
% corrected in the \head function by using a vspace.
\geometry{left=9mm,right=9mm, top=0.8cm+\headerHeight, bottom=0.8cm}

% define variables with empty text so TeX doesn't complain if there aren't
% any sections (yet)
\global\def\lastSectionHead{}

% print edges and repeated header (if available) for each page
\AtBeginPage{
  \put(15, -15){\rule{1cm}{1pt}}
  \put(15, -43){\rule{1pt}{1cm}}
  \put(15, -830){\rule{1cm}{1pt}}
  \put(15, -830){\rule{1pt}{1cm}}
  \put(554, -15){\rule{1cm}{1pt}}
  \put(581.5, -43){\rule{1pt}{1cm}}
  \put(554, -830){\rule{1cm}{1pt}}
  \put(581.5, -830){\rule{1pt}{1cm}}
  \write\posout{- !ruby/object:Page}
  \write\posout{u questions:}
  \put(21.1,\headerHeightForPut){\@ifundefined{lastSectionHeadReal}{}{\sect{\lastSectionHeadReal}}}
  \global\edef\lastSectionHeadReal{\lastSectionHead}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% some style options
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\DeclareOption*{%
\PassOptionsToClass{\CurrentOption}{scrartcl}%
}
\ProcessOptions\relax

\pagestyle{empty}

\renewcommand{\baselinestretch}{1}
\setlength\tabcolsep{0pt}

\setlength\parindent{0pt}

\definecolor{gray}{rgb}{.88,.88,.88}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% common functions to write out data, headers, checkboxes, ...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% rename some variables(?)
\newcommand{\dozent}[1]{\def\doz{#1}}
\newcommand{\vorlesung}[1]{\def\vor{#1}}
\newcommand{\semester}[1]{\def\sem{#1}}
\newcommand{\dbtable}[1]{\def\dbt{#1}}
\newcommand{\tutoren}[1]{\def\tut{#1}}

% set output file
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

% places everything into a box as wide as the page, thus preventing its contents
% from being interrupted by a page break. Moves its content slightly to the left
% to combat the hardcoded padding inside the box. Usage:
% \preventBreak{%
%    some content
% }
\newcommand{\preventBreak}[1]{
  \makebox[192mm][l]{\hspace*{-0.8mm}
    #1
  }
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% header related stuff
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prints main caption and barcode
\newcommand{\head}[2]{
  \write\posout{--- !ruby/object:AbstractForm}
  \write\posout{db_table: \dbt}
  \write\posout{pages: }
  \write\posout{- !ruby/object:Page }
  \write\posout{u questions: }
  \vspace*{-0.4cm}
  \vspace*{-\headerHeight}
  \Huge{#1}\normalsize
  \hfill\raisebox{-4.1mm}{\includegraphics[width=3cm,height=1cm]{barcode#2.pdf}}\\
  \vspace*{-2mm}
}

% prints data that identifies what/who is being evaluated
\newcommand{\dataline}[3]{
  \textbf{#1:} \vor \hfill\textbf{#2:} \doz \hfill\textbf{#3:} \sem \\[0.2em]
}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% sections
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Note: all headers must have a black bottom line that matches the \hline which is used to
% separate each question. This is due to the section being repeated at the top of the page but its
% z-index is lower than the question's. If required, you can disable the hline for the question
% following the section header by calling: \renewcommand{\hline}{}
%
% Adjust the height of each header

% provides _large_ grey header to separate questions into groups
\newcommand{\sectlarge}[1]{
    \fcolorbox{black}{gray}{%
      % allow 2*1.6mm for the border; the phantoms ensure each box has the
      % same height
      \makebox[188.8mm][c]{\Large{\phantom{\"Ay}#1\phantom{\"Ay}}}
    }
  %}
  % prevent toprule for the following question
  \renewcommand{\hline}{}
  \vspace*{-0.5mm}
}

% provides _small_ grey header to separate questions into groups
\newcommand{\sectsmall}[1]{
  \colorbox{gray}{% no idea why it isn't 192mm
    \makebox[189.1mm][l]{\textbf{#1\phantom{\"Ay}}}
  }
  % line up the section's bottom with the question's hline
  \vspace*{-0.5mm}
}

\newcommand{\secte}{
  \vspace{-1.2em}\rule{192mm}{1.5pt}\vspace{0.5em}
}

% used at the end of the page to mark the end of a comment field
\newcommand{\separator}[1]{
  \vspace{-1.2em}\rule{19.2cm}{#1}\\
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Questions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\NewDocumentCommand\quest{d<> m m o o o o o o}{%
  %This is to test if we have a Multiple Choice Question
  \IfNoValueTF{#1}{% single choice question
    \SaveNormalInfo[#3][#2]
  }{% multiple choice question
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
  % Available space: 210mm - 2*9mm = 192mm
  \IfNoValueTF{#9}{
  \IfNoValueTF{#8}{
  \IfNoValueTF{#7}{
  \IfNoValueTF{#6}{
  \IfNoValueTF{#5}{% 1 answer
    \Huge{Wir sind doch nicht in der DDR hier!}\\
  }{% 2 answers, is aligned to the 5-answers question
    \preventBreak{%
      \begin{tabular}{p{8cm}>{\centering}p{18.6mm}>{\centering}p{24.95mm}p{68.45mm}}
	\hline\\[-0.8em]
	\multirow{2}{7.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] &   \\
				& \small#4    & \small#5    &
      \end{tabular}
    }
  }}{% 3 answers
    \preventBreak{%
      \begin{tabular}{p{8cm}>{\centering}p{18.6mm}>{\centering}p{74.8mm}>{\centering}p{18.6mm}p{0cm}}
	\hline\\[-0.8em]
	\multirow{2}{7.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] & \bxs[3][#6] &  \\
				& \small#4    & \small#5    & \small#6    &
      \end{tabular}
    }
  }}{% 4 answers
    \preventBreak{%
      \begin{tabular}{p{8cm}>{\centering}p{18.6mm}>{\centering}p{37.4mm}>{\centering}p{37.4mm}>{\centering}p{18.6mm}p{0mm}}
	\hline\\[-0.8em]
	\multirow{2}{7.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] & \bxs[3][#6] & \bxs[4][#7] & \\
				&  \small#4   & \small#5    & \small#6    & \small#7    &
      \end{tabular}
    }
  }}{% 5 answers
    \preventBreak{%
      \begin{tabular}{p{8cm}>{\centering}p{18.6mm}>{\centering}p{24.95mm}>{\centering}p{24.9mm}>{\centering}p{24.95mm}>{\centering}p{18.6mm}p{0mm}}
	\hline\\[-0.8em]
	\multirow{2}{7.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] & \bxs[3][#6] & \bxs[4][#7] & \bxs[5][#8] & \\
				& \small#4    & \small#5    & \small#6    & \small#7    & \small#8    &
      \end{tabular}
    }
  }}{% 6 answers
    \preventBreak{%
      \begin{tabular}{p{8cm}>{\centering}p{18.6mm}>{\centering}p{18.7mm}>{\centering}p{18.7mm}>{\centering}p{18.7mm}>{\centering}p{18.7mm}>{\centering}p{18.6mm}p{0mm}}
	\hline\\[-0.8em]
	\multirow{2}{7.4cm}{#3} & \bxs[1][#4] & \bxs[2][#5] & \bxs[3][#6] &  \bxs[4][#7] & \bxs[5][#8] & \bxs[6][#9] & \\
				& \small#4    & \small#5    & \small#6    & \small#7     & \small#8    & \small#9    &
      \end{tabular}
    }
  }
  \vspace{0em} % for some reason this is required, otherwise "Argument of \@imakebox has an extra }." is raised
  % enable hline for the following questions
  \let\hline\hlineback
} % end of command quest



% legacy code used to generate question text for special questions
\newcommand{\printspecialheader}[1]{
  \makebox[1.0\textwidth][l]{\hspace*{0.0cm}\textbf{#1:}}\vspace{0.1cm}
}


% prints tutors if they have been defined
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

% comment field
\newcommand{\comment}[3]{\write\posout{u - !ruby/object:Question}
  \write\posout{uu choice: }
  \write\posout{uu qtext: "#1"}
  \write\posout{uu save_as: "#3"}
  \write\posout{uu type: text}
  \write\posout{uu db_column: "#2"}
  \vspace{0.35cm}
  \separator{\arrayrulewidth}
  #1\hspace*{0.5cm}\write\posout{uu boxes:}\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: start}\write\posout{uuu height: 650000}\SaveMyYPos\hfill\write\posout{uu- !ruby/object:Box}\write\posout{uuu type: end}\SaveMyYPos\\\write\posout{uu- !ruby/object:Box}\SaveMyYPos\vspace*{3200000sp}
  \write\posout{uuu height: 3200000}
  \write\posout{uuu width: 39020584}
}

% makes the following page act as comment field
\newcommand{\backpagecomment}[1]{
  \newpage
  \mbox{}
  \write\posout{u - !ruby/object:Question}
  \write\posout{uu type: text_wholepage}
  \write\posout{uu db_column: "#1"}
  \write\posout{uu save_as: "vcomment"}
  \let\lastSectionHeadReal\undefined
}
