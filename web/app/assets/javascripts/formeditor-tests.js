/* This fail hosts all tests and related helper functions. It is only
 * loaded in rails development mode. The tests are not run by default,
 * but can be issued using $F().runTests(). You can also comment in the
 * block below to run them on each reload. A custom form is used for the
 * tests, it is specified at the bottom of this file. */


//$(document).ready(function() {
//  $F().runTests();
//});


/* Runs all available tests. */
FormEditor.prototype.runTests = function() {
  try {
    $F().loadTestForm();
  } catch(err) {
    $F().warn("Failed to load default test form. Aborting.");
    $F().log(err);
    return;
  }

  var l;

  l = $(".page").length;
  $F().test(l === 1, "There should be only one page element, but "+l+" have been found.");

  l = $(".section").length;
  $F().test(l === 1, "There should be only one section element, but "+l+" have been found.");

  // Page basics: adding, removing
  var newPage = $F().findLinksByText("#form_editor", "Create New Page");
  $F().test(newPage.length === 1, "There should be only one new page link, but "+newPage.length+" have been found.");
  $F().test(function() { newPage.click() }, "Creating a new page didn’t work.");
  $F().test(function() { $(".page > a.delete").last().click() }, "Deleting a page break didn’t work.");
  $F().checkForNoOps("Adding and deleting a page isn’t no-op.");

  // Section basics: adding, removing
  $F().loadTestForm();
  var newSection = $F().findLinksByText("#form_editor", "Create New Section");
  $F().test(newSection.length === 1, "There should be only one new section link, but "+newSection.length+" have been found.");
  $F().test(function() { newSection.click() }, "Creating a new section didn’t work.");
  $F().test(function() { $(".section > .header > .delete").last().click() }, "Deleting a section didn’t work.");
  $F().checkForNoOps("Adding and deleting a section isn’t no-op.");

  // Question basics: adding, removing
  $F().loadTestForm();
  var newQuestion = $F().findLinksByText("#form_editor", "Create New Question");
  $F().test(newQuestion.length === 1, "There should be only one new question link, but "+newQuestion.length+" have been found.");
  $F().test(function() { newQuestion.click() }, "Creating a new question didn’t work.");
  $F().test(function() { $(".question > .header > .delete").last().click() }, "Deleting a question didn’t work.");
  $F().checkForNoOps("Adding and deleting a question isn’t no-op.");
};

/* Checks that the current state of the DOM is equal to the original
 * form when converting the DOM to YAML. Effectively checks that the
 * operations so far have yielded nothing. */
FormEditor.prototype.checkForNoOps = function(message) {
  this.dom2yaml();
  this.test(this.getTestForm() === $("#form_content").val(), message);
};

/* Finds links (a-elements) by their given text contents.
 * @param  limiter: jQuery Selector that limits where to search for "a"s
 * @param  text: The text a link must contain to be selected
 * @return array of the a-elements found */
FormEditor.prototype.findLinksByText = function(limiter, text) {
  return $(limiter + " a").filter(function(ind, el) { return $(el).text().indexOf(text) >= 0 });
};

/* Sets the text area’s value and also makes the FormEditor load or
 * render that form */
FormEditor.prototype.loadTestForm = function() {
  $("#form_content").val(this.getTestForm());
  this.loadFormFromTextbox();
};

/* @returns the default form in YAML format as string */
FormEditor.prototype.getTestForm = function() {
  return (<r><![CDATA[--- !ruby/object:AbstractForm
db_table: "evaldata_summerterm12_lectures"
texfoot: ""
texhead: " "
title:
  :de: "Umfrage zur Qualität der Lehre"
  :en: "Survey Regarding the Quality of Teaching"
intro:
  :de: "Diese Evaluation wird von der Studienkommission in Zusammenarbeit mit der Fachschaft MathPhys durchgeführt. Dieser Bogen soll helfen, die Lehre zu verbessern bzw. Lehrveranstaltung guter Qualität zu erhalten. Auch in eurem Interesse bitten wir euch, den Bogen sorgfältig und deutlich lesbar auszufüllen. Kreuze so \\checkLikeThis{} an und verbessere Dich ggf. so \\correctLikeThis{}."
  :en: "This survey is carried out by the committee of studies in cooperation with the Fachschaft MathPhys. Its purpose is to improve or maintain the standards of teaching. In your own best interest, please complete this questionnaire thoroughly and legibly. Mark like \\checkLikeThis{} and correct yourself using \\correctLikeThis{}."
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
              :de: "Mit welchem \\emph{Abschlussziel} studieren Sie?"
              :en: "Which \\emph{degree} will you receive at the end of your studies?"
            type: "square"
            db_column: "v_central_degree"
            visualizer: "horizontal_bars"
            boxes:
              - !ruby/object:Box
                text: "Bachelor"
              - !ruby/object:Box
                text:
                  :de: "Staatsexamen\\linebreak(Lehramt)"
                  :en: "Staatsexamen\\linebreak\\emph{including Lehramt} (State Examination \\emph{including Civil \\textls[-15]{Service Examination)}}"
              - !ruby/object:Box
                text:
                  :de: "Staatsexamen\\linebreak\\textbf{(ohne Lehramt)}"
                  :en: "Staatsexamen\\linebreak\\emph{excluding Lehramt} (State Examination \\emph{excluding Civil \\textls[-15]{Service Examination)}}"
              - !ruby/object:Box
                text:
                  :de: "Kirchlicher Abschluss"
                  :en: "Kirchlicher Abschluss\\linebreak\\mbox{(Ecclesiastical Degree)}"
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
              :en: "Please indicate the \\emph{field of study} in which you are attending this course:"
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
              :de: "Bitte geben Sie Ihr Fachsemester in \\emph{diesem Studienfach} an:"
              :en: "In which \\emph{subject-related semester of this field of study} are you currently studying?"
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
              :de: "Ist diese Lehrveranstaltung für Sie eine \\emph{Pflichtveranstaltung}?"
              :en: "Is this an obligatory course for you?"
            type: "square"
            db_column: "v_central_required_course"
            visualizer: "histogram_no_cmp"
            boxes:
              - !ruby/object:Box
                text:
                  :de: "\\mbox{ja, ich muss \\emph{genau}}\\linebreak\\mbox{\\emph{diese} besuchen}"
                  :en: "\\mbox{yes, I have to attend}\\linebreak\\mbox{\\emph{exactly this one}}"
              - !ruby/object:Box
                text:
                  :de: "nein, ich könnte auch eine andere besuchen"
                  :en: "no, I could attend\\linebreak another one"
          - !ruby/object:Question
            qtext:
              :de: "\\emph{Bevor} Sie diese Lehrveranstaltung besucht haben: Wie hoch war Ihr Interesse am Thema der Lehrveranstaltung?"
              :en: "How much were you \\emph{interested} in the topic of the course \\emph{before} attending it?"
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
                  :en: "very little"]]></r>).toString();
};
