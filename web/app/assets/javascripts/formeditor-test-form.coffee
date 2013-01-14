# Using coffeescript here to get a browser-compatible here document.
# Backslashes are still a problem, so they are simply removed here
# as their only importance is for displaying the form when TeXing it.

window.formEditorTestForm = """--- !ruby/object:AbstractForm
texfoot: ""
texhead: " "
title:
  :de: "Umfrage zur Qualität der Lehre"
  :en: "Survey Regarding the Quality of Teaching"
intro: "This survey is carried out by the committee of studies in cooperation with the Fachschaft MathPhys. Its purpose is to improve or maintain the standards of teaching. In your own best interest, please complete this questionnaire thoroughly and legibly. Mark like checkLikeThis{} and correct yourself using correctLikeThis{}."
lecturer_header:
  :de:
    :both: "Fragen zur Vorlesung (Dozent/in: #1, Bögen: #2)"
    :female: "Fragen zur Vorlesung (Dozentin: #1, Bögen: #2)"
    :male: "Fragen zur Vorlesung (Dozent: #1, Bögen: #2)"
  :en: "Questions concerning the lecture (Lecturer: #1, Sheets: #2)"
pages:
  - !ruby/object:Page
    tex_at_top: ""
    tex_at_bottom: ""
    sections:
      - !ruby/object:Section
        title:
          :de: "Allgemeine Fragen"
          :en: "General Questions"
        questions:
          - !ruby/object:Question
            qtext:
              :de: "Mit welchem emph{Abschlussziel} studieren Sie?"
              :en: "Which emph{degree} will you receive at the end of your studies?"
            type: "square"
            db_column: "v_central_degree"
            visualizer: "horizontal_bars"
            boxes:
              - !ruby/object:Box
                text: "Bachelor"
              - !ruby/object:Box
                text:
                  :de: "Staatsexamenlinebreak(Lehramt)"
                  :en: "Staatsexamenlinebreakemph{including Lehramt} (State Examination emph{including Civil textls[-15]{Service Examination)}}"
              - !ruby/object:Box
                text:
                  :de: "Staatsexamenlinebreaktextbf{(ohne Lehramt)}"
                  :en: "Staatsexamenlinebreakemph{excluding Lehramt} (State Examination emph{excluding Civil textls[-15]{Service Examination)}}"
              - !ruby/object:Box
                text:
                  :de: "Kirchlicher Abschluss"
                  :en: "Kirchlicher Abschlusslinebreakmbox{(Ecclesiastical Degree)}"
              - !ruby/object:Box
                text: "Master"
              - !ruby/object:Box
                text:
                  :de: "Diplom"
                  :en: "Diplom (Diploma)"
              - !ruby/object:Box
                text: "Magister"
              - !ruby/object:Box
                text:
                  :de: "Promotion"
                  :en: "Ph.D."
              - !ruby/object:Box
                text:
                  :de: "Sonstiges"
                  :en: "others"
          - !ruby/object:Question
            qtext:
              :de: "Bitte geben Sie Ihr Studienfach an, innerhalb dessen Sie diese Lehrveranstaltung besuchen:"
              :en: "Please indicate the emph{field of study} in which you are attending this course:"
            type: "square"
            db_column: "v_central_major"
            last_is_textbox: 25
            visualizer: "horizontal_bars"
            boxes:
              - !ruby/object:Box
                text:
                  :de: "Mathematik"
                  :en: "Mathematics"
              - !ruby/object:Box
                text:
                  :de: "Physik"
                  :en: "Physics"
              - !ruby/object:Box
                text:
                  :de: "Informatik"
                  :en: "Computer Science"
              - !ruby/object:Box
                text:
                  :de: "Sonstiges"
                  :en: "others"
          - !ruby/object:Question
            qtext:
              :de: "Bitte geben Sie Ihr Fachsemester in emph{diesem Studienfach} an:"
              :en: "In which emph{subject-related semester of this field of study} are you currently studying?"
            type: "square"
            db_column: "v_central_semester"
            visualizer: "horizontal_bars"
            boxes:
              - !ruby/object:Box
                text: "1-3"
              - !ruby/object:Box
                text: "4-6"
              - !ruby/object:Box
                text: "7-10"
              - !ruby/object:Box
                text: "> 10"
          - !ruby/object:Question
            qtext:
              :de: "Ist diese Lehrveranstaltung für Sie eine emph{Pflichtveranstaltung}?"
              :en: "Is this an obligatory course for you?"
            type: "square"
            db_column: "v_central_required_course"
            visualizer: "histogram_no_cmp"
            boxes:
              - !ruby/object:Box
                text:
                  :de: "mbox{ja, ich muss emph{genau}}linebreakmbox{emph{diese} besuchen}"
                  :en: "mbox{yes, I have to attend}linebreakmbox{emph{exactly this one}}"
              - !ruby/object:Box
                text:
                  :de: "nein, ich könnte auch eine andere besuchen"
                  :en: "no, I could attendlinebreak another one"
          - !ruby/object:Question
            qtext:
              :de: "emph{Bevor} Sie diese Lehrveranstaltung besucht haben: Wie hoch war Ihr Interesse am Thema der Lehrveranstaltung?"
              :en: "How much were you emph{interested} in the topic of the course emph{before} attending it?"
            type: "square"
            db_column: "v_central_interest"
            visualizer: "histogram"
            boxes:
              - !ruby/object:Box
                text:
                  :de: "sehr hoch"
                  :en: "very much"
              - !ruby/object:Box
              - !ruby/object:Box
              - !ruby/object:Box
              - !ruby/object:Box
                text:
                  :de: "sehr gering"
                  :en: "very little"
"""
