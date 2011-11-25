\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{eval}[2011/05/12 Evaluationsbögen]

\LoadClass[twoside,8pt]{scrartcl}

\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage{amssymb}
\RequirePackage{array}
\RequirePackage{babel}
\RequirePackage{bophook}
\RequirePackage{color}
\RequirePackage{geometry}
\RequirePackage{ifthen}
\RequirePackage{multirow}
\RequirePackage{graphicx}
\RequirePackage{microtype}
\RequirePackage{tabularx}
\RequirePackage{tokeniz0r}
\RequirePackage{tgheros}
\RequirePackage[breakall]{truncate}
\RequirePackage{xparse}
\RequirePackage{xstring}
\renewcommand{\rmdefault}{\sfdefault}

% centered, fixed width table column
\newcolumntype{C}[1]{>{\centering\arraybackslash}p{#1}}

% backup hline command. hline will be disabled when a new section begins in order to avoid several
% rules. hlineback is used to restore hline functionality after each question.
\let\hlineback\hline

% Variable used to store further answers until they can be printed into the question table. See
% \moreAnswers for a explanation on how to use this.
\def\hasMoreAnswers{}

% choice counter, used to increment each answer box by one. Reset at the start of \quest
\newcounter{choiceCounter}
% answer counter, used to count the # of answers. Currently only used to be able to print out the
% db field for multiple choice questions correctly. Reset at the end of \quest.
\newcounter{answerCounter}

% shorthand to write information into posout file
\def\wPosout{\write\posout}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% for-each-page stuff (e.g. headers, edges)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\geometry{left=9mm,right=9mm, top=0.6cm, bottom=0.7cm}

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
  \wPosout{- !ruby/object:Page}
  \wPosout{u questions:}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% some style options
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\DeclareOption*{%
\PassOptionsToClass{\CurrentOption}{scrartcl}%
}
\ProcessOptions\relax

\renewcommand{\TruncateMarker}{\textasciitilde}

\pagestyle{empty}

\renewcommand{\baselinestretch}{1}
\setlength\tabcolsep{0pt}

\setlength\parindent{0pt}

\definecolor{gray}{rgb}{.88,.88,.88}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% common functions to write out data, headers, checkboxes, ...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% these two print out how boxes should be checked and/or corrected. Boxes are sized and aligned to
% be used in vanilla text
\newcommand{\checkLikeThis}{{\LARGE \raisebox{-0.1mm}{$\medsquare$\kern0em$\boxtimes$\kern0em$\medsquare$\kern0em$\medsquare$}}}
\newcommand{\correctLikeThis}{{\LARGE \raisebox{-0.1mm}{$\medsquare$\kern0em$\filledmedsquare$\kern0em$\medsquare$\kern0em$\boxtimes$}}}


% let the user store data using these commands
\newcommand{\dozent}[1]{\def\doz{#1}}
\newcommand{\vorlesung}[1]{\def\vor{#1}}
\newcommand{\semester}[1]{\def\sem{#1}}
\newcommand{\dbtable}[1]{\def\dbt{#1}}
\newcommand{\tutoren}[1]{\def\tut{#1}}
\newcommand{\noAnswerText}[1]{\def\noAnswTxt{#1}}

% set output file
\newwrite\posout
\openout\posout\jobname.posout

\def\Source{}

\def\SaveMyYPos{
  \pdfsavepos
	\wPosout{uuu x: \number\pdflastxpos}
	\wPosout{uuu y: \number\pdflastypos}
}

\def\tutorbox[#1][#2]{%
  \wPosout{uuu choice: "#1"}
  \vspace{-0.3cm}
  \truncate{3cm}{#2}
}

\def\bx{\huge{$\Box$}\normalsize\SaveMyYPos}

% prints a box and stores its position in the posout file along with the given value. If no value
% is given the global choiceCounter is incremented and its value is printed into the posout file
%  instead.
\newcommand{\bxs}[1][]{%
  \vspace{-0.8em}
  \wPosout{uu- !ruby/object:Box}
  \IfStrEq{#1}{}{
    \stepcounter{choiceCounter}
    \edef\saveText{uuu choice: "\arabic{choiceCounter}"}
    \wPosout\expandafter{\saveText}
  }{\wPosout{uuu choice: "#1"}}
  \hspace{0.5em}
  \huge{$\Box$}\normalsize\SaveMyYPos
}

\def\bxss[#1]{%
  \vspace{-0.8em}
  \wPosout{uu- !ruby/object:Box}
  \wPosout{uuu choice: "#1"}
  \hspace{-0.43cm}
  \huge{$\Box$}\normalsize\SaveMyYPos
}

\newcommand{\boxfixed}[2]{
  \bxss[#2]
  \makebox[2.31cm][l]{\truncate{2.31cm}{\raisebox{0.4ex}{#2}}}
  \makebox[0.05cm]{}
}

\newcommand{\boxfixedempty}{
  \phantom{\bxss[]}
  \makebox[2.31cm][l]{}
  \makebox[0.05cm]{}
}

\newcommand{\boxvariable}[2]{
  \bxss[#1]\raisebox{0.4ex}{#2}
}

% writes the posout information for multiple choice questions give the database prefix
% as first option and the amount of boxes as second.
% The letters (a, b, c, ..., (noansw)) will be added automatically
\newcounter{multiCounter}
\def\SaveMultiInfo[#1][#2]{%
  \wPosout{u - !ruby/object:Question}
  \wPosout{uu type: square}
  \wPosout{uu db_column: }
  \setcounter{multiCounter}{0}
  \whiledo{\value{multiCounter} < #2}{
    \stepcounter{multiCounter}
    \edef\saveText{uu - #1\alph{multiCounter}}
    \wPosout\expandafter{\saveText}
  }
  \ifthenelse{\boolean{noanswer}}{\wPosout{uu - #1noansw}}{}
  \wPosout{uu boxes:}
}

% writes the posout information for single choice questions
\def\SaveNormalInfo[#1]{%
  \wPosout{u - !ruby/object:Question}
  \wPosout{uu type: square}
  \wPosout{uu db_column: #1}
  \wPosout{uu boxes:}
}

% places everything into a box as wide as the page, thus preventing its contents
% from being interrupted by a page break. Moves its content slightly to the left
% to combat the hardcoded padding inside the box. Usage:
% \preventBreak{%
%    some content
% }
\newcommand{\preventBreak}[1]{
  \begin{tabular}[t]{p{192mm}}
    #1
  \end{tabular}
  \vspace*{-1.8mm}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% header related stuff
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prints main caption and barcode
\newcommand{\head}[2]{
  \wPosout{--- !ruby/object:AbstractForm}
  \wPosout{db_table: \dbt}
  \wPosout{pages: }
  \wPosout{- !ruby/object:Page }
  \wPosout{u questions: }
  \vspace*{-1.85mm}
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

% provides _small_ grey header to separate questions into groups. The phantom part ensures each
% box has the same height (except for weird characters)
\newcommand{\sect}[1]{
  \colorbox{gray}{% no idea why it has to be this width
    \makebox[189.1mm][l]{\textbf{#1\phantom{\"Ay}}}
  }

  % newline required to put separator below text
  \vspace*{1.6mm}\separator{\arrayrulewidth}

  \vspace*{-3.1mm}
  \renewcommand{\hline}{}
}

\newcommand{\secte}{
  \vspace{-1.2em}\rule{192mm}{1.5pt}\vspace{0.5em}
}

% used at the end of the page to mark the end of a comment field
\newcommand{\separator}[1]{
  \vspace{-1.15em}\rule{19.2cm}{#1}\\
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Questions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\newboolean{single}
\newboolean{noanswer}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% helper commands that print each of the tables depending on how many answers are required.

%%%% these questions automatically add the "no answer" box to the end %%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 2 answers, is aligned to the 5-answers question
\newcommand{\tabNoAnswTwo}[3]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}@{\hspace*{58.09mm}}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        & \bxs[99]              &\\
                            & \small#2    & \small#3    & \small\noAnswTxt      &
    \hasMoreAnswers
  \end{tabular}
}

% 3 answers + no answer, i.e. 47.1mm more space, thus 15.7mm additional space between boxes
\newcommand{\tabNoAnswThree}[4]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{7.85mm}}C{31.4mm}C{31.4mm}@{\hspace*{7.85mm}}C{15.75mm}p{0cm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        & \bxs        & \bxs[99]              &\\
                            & \small#2    & \small#3    & \small#4    & \small\noAnswTxt      &
    \hasMoreAnswers
  \end{tabular}
}

% 4 answers + no answer, i.e. 31.4mm more space, thus 7.85mm additional space between boxes
\newcommand{\tabNoAnswFour}[5]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{3.925mm}}C{23.55mm}C{23.55mm}C{23.55mm}@{\hspace*{3.925mm}}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs      & \bxs        & \bxs        & \bxs        & \bxs[99]              &\\
                            & \small#2  & \small#3    & \small#4    & \small#5    & \small\noAnswTxt      &
    \hasMoreAnswers
  \end{tabular}
}

% 5 answers + no answer, i.e. 15.7mm more space, thus 3.14mm additional space between boxes
\newcommand{\tabNoAnswFive}[6]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}C{18.84mm}C{18.84mm}C{18.84mm}@{\hspace*{1.57mm}}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs      & \bxs        & \bxs        & \bxs        & \bxs        & \bxs[99]              &\\
                            & \small#2  & \small#3    & \small#4    & \small#5    & \small#6    & \small\noAnswTxt      &
    \hasMoreAnswers
  \end{tabular}
}

% 6 answers + no answer
\newcommand{\tabNoAnswSix}[7]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        & \bxs        &  \bxs        & \bxs        & \bxs        & \bxs[99]              &\\
                            & \small#2    & \small#3    & \small#4    & \small#5     & \small#6    & \small#7    & \small\noAnswTxt      &
    \hasMoreAnswers
  \end{tabular}
}

%%%% these questions do not add a "no answer" box to the end %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1 answer
\newcommand{\tabOne}[2]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}@{\hspace*{73.84mm}}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        &      &   \\
                            & \small#2    &      &
    \hasMoreAnswers
  \end{tabular}
}

% 2 answers, is aligned to the 5-answers question
\newcommand{\tabTwo}[3]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}@{\hspace*{73.84mm}}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        &   \\
                            & \small#2    & \small#3    &
    \hasMoreAnswers
  \end{tabular}
}

% 3 answers
\newcommand{\tabThree}[4]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{15.7mm}}C{47.15mm}@{\hspace*{15.7mm}}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        & \bxs        &  \\
                            & \small#2    & \small#3    & \small#4    &
    \hasMoreAnswers
  \end{tabular}
}

% 4 answers
\newcommand{\tabFour}[5]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{7.85mm}}C{31.4mm}C{31.4mm}@{\hspace*{7.85mm}}C{15.75mm}p{0cm}} % TODO
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        & \bxs        & \bxs        & \\
                            & \small#2    & \small#3    & \small#4    & \small#5    &
    \hasMoreAnswers
  \end{tabular}
}

% 5 answers
\newcommand{\tabFive}[6]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{3.925mm}}C{23.55mm}C{23.55mm}C{23.55mm}@{\hspace*{3.925mm}}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        & \bxs        & \bxs        & \bxs        & \\
                            & \small#2    & \small#3    & \small#4    & \small#5    & \small#6    &
    \hasMoreAnswers
  \end{tabular}
}

% 6 answers
\newcommand{\tabSix}[7]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}@{\hspace*{1.57mm}}C{18.84mm}C{18.84mm}C{18.84mm}C{18.84mm}@{\hspace*{1.57mm}}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs       & \bxs        & \bxs        &  \bxs        & \bxs        &  \bxs        & \\
                            & \small#2   & \small#3    & \small#4    & \small#5     & \small#6    &  \small#7    &
    \hasMoreAnswers
  \end{tabular}
}

% 7 answers
\newcommand{\tabSeven}[8]{
  \begin{tabular}[t]{p{8.2cm}C{15.75mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.7mm}C{15.75mm}p{0mm}}
    \hline\\[-0.8em]
    \multirow{2}{7.6cm}{#1} & \bxs        & \bxs        & \bxs        &  \bxs        & \bxs        & \bxs        & \bxs           &\\
                            & \small#2    & \small#3    & \small#4    & \small#5     & \small#6    & \small#7    & \small#8       &
    \hasMoreAnswers
  \end{tabular}
}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% allows up to six possible answers. Arguments are as follows:
% \quest
% <(single|multi) (noanswer)> All arguments are optional. noanswer will add a now answer box to
%                             at the end. Single/multi make the question single/multi choice.
% {db_table_column_name}      multiple choice question get the names: namea, nameb, namec, and so
%                             on. If the question also has a noanswer box it will be named namenoansw
% {first answer}
% {second answer}
% ...
\NewDocumentCommand\quest{D<>{} m m o o o o o o}{%
  % set defaults
  \setboolean{single}{true}
  \setboolean{noanswer}{true}
  \setcounter{choiceCounter}{0}

  \IfSubStr{#1}{single}{\setboolean{single}{true}}{}
  \IfSubStr{#1}{multi}{\setboolean{single}{false}}{}
  \IfSubStr{#1}{noanswer}{\setboolean{noanswer}{true}}{\setboolean{noanswer}{false}}

  %This is to test if we have a Multiple Choice Question
  \ifthenelse{\boolean{single}}{% single choice question
    \SaveNormalInfo[#2]
  }{% multiple choice question
    \IfNoValueTF{#9}{
    \IfNoValueTF{#8}{
    \IfNoValueTF{#7}{
    \IfNoValueTF{#6}{
    \IfNoValueTF{#5}{
      \addtocounter{answerCounter}{1}
    }{\addtocounter{answerCounter}{2}}
    }{\addtocounter{answerCounter}{3}}
    }{\addtocounter{answerCounter}{4}}
    }{\addtocounter{answerCounter}{5}}
    }{\addtocounter{answerCounter}{6}}
    \SaveMultiInfo[#2][\arabic{answerCounter}]
  }
  % move question closer to the previous one
  %\vspace*{-3.5mm}

  % Print the question, depending on how many answers are given
  \ifthenelse{\boolean{noanswer}}{ % "no answer" checkbox is added automatically
    \IfNoValueTF{#9}{
    \IfNoValueTF{#8}{
    \IfNoValueTF{#7}{
    \IfNoValueTF{#6}{
    \IfNoValueTF{#5}{% 1 answer
      \Huge{Wir sind doch nicht in der DDR hier!}\\
    }{\tabNoAnswTwo{#3}{#4}{#5}}
    }{\tabNoAnswThree{#3}{#4}{#5}{#6}}
    }{\tabNoAnswFour{#3}{#4}{#5}{#6}{#7}}
    }{\tabNoAnswFive{#3}{#4}{#5}{#6}{#7}{#8}}
    }{\tabNoAnswSix{#3}{#4}{#5}{#6}{#7}{#8}{#9}}
  }{ % "no answer" checkbox NOT included
    \IfNoValueTF{#9}{
    \IfNoValueTF{#8}{
    \IfNoValueTF{#7}{
    \IfNoValueTF{#6}{
    \IfNoValueTF{#5}{% 1 answer
      \Huge{Wir sind doch nicht in der DDR hier!}\\
    }{\tabTwo{#3}{#4}{#5}}
    }{\tabThree{#3}{#4}{#5}{#6}}
    }{\tabFour{#3}{#4}{#5}{#6}{#7}}
    }{\tabFive{#3}{#4}{#5}{#6}{#7}{#8}}
    }{\tabSix{#3}{#4}{#5}{#6}{#7}{#8}{#9}}
  }%
  % end lines with %-signs, because otherwise there will be too much space between questions
  % enable hline for the following questions
  \let\hline\hlineback%
  % reset answers for following question
  \def\hasMoreAnswers{}%
  % reset answer counter for next question
  \setcounter{answerCounter}{0}%
} % end of command quest


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% allows up to seven possible answers directly *before* a \quest. It is not suitable to be used on
% its own. The alignment is determined by \quest, so you cannot have a different raster for each
% line.
% Currently only supports single choice questions.
% \moreAnswers
% {first answer}
% {second answer}
% ...
\NewDocumentCommand\moreAnswers{o o o o o o o}{%
  \IfNoValueTF{#7}{
  \IfNoValueTF{#6}{
  \IfNoValueTF{#5}{
  \IfNoValueTF{#4}{
  \IfNoValueTF{#3}{
  \IfNoValueTF{#2}{
    \addtocounter{answerCounter}{1}
    \edef\hasMoreAnswers{\hasMoreAnswers \unexpanded{
      \\[1mm] & \bxs     &
      \\      & \small#1}}
  }{\addtocounter{answerCounter}{2}
    \edef\hasMoreAnswers{\hasMoreAnswers \unexpanded{
      \\[1mm] & \bxs     & \bxs     &
      \\      & \small#1 & \small#2}}
  }}{\addtocounter{answerCounter}{3}
    \edef\hasMoreAnswers{\hasMoreAnswers \unexpanded{
      \\[1mm] & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3}}
  }}{\addtocounter{answerCounter}{4}
    \edef\hasMoreAnswers{\hasMoreAnswers \unexpanded{
      \\[1mm] & \bxs    & \bxs     & \bxs     & \bxs     &
      \\      &\small#1 & \small#2 & \small#3 & \small#4}}
  }}{\addtocounter{answerCounter}{5}
    \edef\hasMoreAnswers{\hasMoreAnswers \unexpanded{
      \\[1mm] & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3 & \small#4 & \small#5}}
  }}{\addtocounter{answerCounter}{6}
    \edef\hasMoreAnswers{\hasMoreAnswers \unexpanded{
      \\[1mm] & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3 & \small#4 & \small#5 & \small#6}}
  }}{\addtocounter{answerCounter}{7}
    \edef\hasMoreAnswers{\hasMoreAnswers \unexpanded{
      \\[1mm] & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     & \bxs     &
      \\      & \small#1 & \small#2 & \small#3 & \small#4 & \small#5 & \small#6 & \small#7}}
  }
}



% legacy code used to generate question text for special questions
\newcommand{\printspecialheader}[1]{
  \makebox[1.0\textwidth][l]{\hspace*{0.0cm}\textbf{#1:}}\vspace{0.1cm}
}


% prints tutors (requires them to have been set before)
\newcommand{\printtutors}[1]{
  \vspace*{-1.4mm}
  \preventBreak{
    \SaveNormalInfo[tutnum]%
    \separator{\arrayrulewidth}%
    #1\\[1.1mm]
    \hspace*{-0.3mm}\begin{tabular}{@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}@{\wPosout{uu- !ruby/object:Box}\bx}p{3.2cm}}
      \tut
    \end{tabular}
    \vspace*{1.7mm}
  }
}

% comment field
\newcommand{\comment}[3]{
  \vspace{-1mm}
  \preventBreak{
    \wPosout{u - !ruby/object:Question}
    \wPosout{uu choice: }
    \wPosout{uu save_as: "#3"}
    \wPosout{uu type: text}
    \wPosout{uu db_column: "#2"}
    \separator{\arrayrulewidth}
    #1\hspace*{0.5cm}\wPosout{uu boxes:}\wPosout{uu- !ruby/object:Box}\wPosout{uuu type: start}\wPosout{uuu height: 650000}\SaveMyYPos\hfill\wPosout{uu- !ruby/object:Box}\wPosout{uuu type: end}\SaveMyYPos\\\wPosout{uu- !ruby/object:Box}\SaveMyYPos\vspace*{3200000sp}
    \wPosout{uuu height: 3200000}
    \wPosout{uuu width: 39020584}
  }
}

% makes the following page act as comment field
\newcommand{\backpagecomment}[1]{
  \newpage
  \mbox{}
  \wPosout{u - !ruby/object:Question}
  \wPosout{uu type: text_wholepage}
  \wPosout{uu db_column: "#1"}
  \wPosout{uu save_as: "vcomment"}
  \let\lastSectionHeadReal\undefined
}
