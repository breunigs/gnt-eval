/* This fail hosts all tests and related helper functions. It is only
 * loaded in rails development mode. The tests are not run by default,
 * but can be issued using $F().runTests(). You can also comment in the
 * block below to run them on each reload. A custom form is used for the
 * tests, it is specified at the bottom of this file. */


$(document).ready(function() {
  $F().runTests();
});


/* Runs all available tests. */
FormEditor.prototype.runTests = function() {
  // prevent submission everywhere
  $("form").attr("action", "");

  try {
    this.loadTestForm();
  } catch(err) {
    this.warn("Failed to load default test form. Aborting.");
    this.log(err);
    return;
  }

  this.animationSpeed = 0;

  var l;

  l = $(".page").length;
  this.test(l === 1, "There should be only one page element, but "+l+" have been found.");

  l = $(".section").length;
  this.test(l === 1, "There should be only one section element, but "+l+" have been found.");

  // Page basics: adding, removing
  var newPage = this.findLinksByText("#form_editor", "Create New Page");
  this.test(newPage.length === 1, "There should be only one new page link, but "+newPage.length+" have been found.");
  this.test(function() { newPage.click() }, "Creating a new page didn’t work.");
  this.test(function() { $(".page > a.delete").last().click() }, "Deleting a page break didn’t work.");
  this.checkForNoOps("Adding and deleting a page isn’t no-op.");

  // Section basics: adding, removing
  this.loadTestForm();
  var newSection = this.findLinksByText("#form_editor", "Create New Section");
  this.test(newSection.length === 1, "There should be only one new section link, but "+newSection.length+" have been found.");
  l = $("input[type=hidden][value=Section]");
  this.test(l.length === 1, "There should be only one (hidden) section header, but "+l.length+" have been found.");
  this.test(function() { newSection.click() }, "Creating a new section didn’t work.");
  l = $("input[type=hidden][value=Section]");
  this.test(l.length === 2, "(After adding section) There should now be two (hidden) section headers, but "+l.length+" have been found.");
  this.test(function() { $(".section > .header > .delete").last().click() }, "Deleting a section didn’t work.");
  this.checkForNoOps("Adding and deleting a section isn’t no-op.");
  l = $("input[type=hidden][value=Section]");
  this.test(l.length === 1, "(After deleting section) There should now be only one (hidden) section header, but "+l.length+" have been found.");

  // Question basics: adding, removing
  this.loadTestForm();
  var newQuestion = this.findLinksByText("#form_editor", "Create New Question");
  this.test(newQuestion.length === 1, "There should be only one new question link, but "+newQuestion.length+" have been found.");
  l = $("input[type=hidden][value=Question]");
  this.test(l.length === 5, "There should be five (hidden) question headers, but "+l.length+" have been found.");
  this.test(function() { newQuestion.click() }, "Creating a new question didn’t work.");
  l = $("input[type=hidden][value=Question]");
  this.test(l.length === 6, "(After adding question) There should now be six (hidden) question headers, but "+l.length+" have been found.");
  this.test(function() { $(".question > .header > .delete").last().click() }, "Deleting a question didn’t work.");
  this.checkForNoOps("Adding and deleting a question isn’t no-op.");
  l = $("input[type=hidden][value=Question]");
  this.test(l.length === 5, "(After deleting question) There should now again be five (hidden) question headers, but "+l.length+" have been found.");

  // Undo/Redo
  this.loadTestForm();
  this.test(function() { $F().findLinksByText("#form_editor", "Create New Question").click(); $("#undo").click(); }, "Undo-ing didn’t work.");
  this.checkForNoOps("Creating a question and undoing isn’t a no-op.");
  this.test(this.undoData.length == 0, "There shouldn’t be any undo step, but "+this.undoData.length+"are possible.");
  this.test(function() { $("#redo").click(); }, "Redo-ing didn’t work.");
  // check typing into field adds undo step.
  // the test is flakey at times, therefore manually calling change which
  // may or may not result in two undo steps being created.
  $("input[id$=column]").first().focus().val("test test").change();
  this.test($F().undoData.length >= 2, "Changing text didn’t create undo event.");

  // expanding
  $(".question").first().find("a.collapse").click();
  setTimeout("$F().runTests2();", 10);
};

FormEditor.prototype.runTests2 = function() {
  this.test($(".question").first().height() >= 650, "Expanding didn’t work, at least the question looks only very small in size.");
  $(".question").first().find("a.collapse").click();
  setTimeout("$F().runTests3();", 10);
};

FormEditor.prototype.runTests3 = function() {
  var q = $(".question").first();
  this.test(q.height() < q.find("h6").outerHeight(true)+10, "The collapsed question is larger than the header.");

  // duplication
  this.test(function() { $(".section > .header > .duplicate").first().click(); }, "Duplicating section didn’t work.");
  this.test($(".section").length === 2, "Should have exactly two sections after duplicating, but don’t.");
  this.test(function() { $(".question > .header > .duplicate").first().click(); }, "Duplicating question didn’t work.");
  this.test($(".question").length === 13, "Should have exactly 13 questions after duplicating, but don’t.");

  // check the generated YAML looks good
  this.dom2yaml();
  var v = $("#form_content").val();
  this.test(v.split("pages:").length-1 === 1, "Needs exactly one list of pages, but it is something else.");
  var p = $("input[type=hidden][value=Page]").length;
  this.test(v.split("  - !ruby/object:Page").length-1 === p, "Page count doesn’t match in YAML and DOM.");
  this.test(v.split("    sections:").length-1 === p, "There are not exactly as many section lists as there are pages.");

  var s = $("input[type=hidden][value=Section]").length;
  this.test(v.split("      - !ruby/object:Section").length-1 === s, "Section count doesn’t match in YAML and DOM.");
  this.test(v.split("        questions:").length-1 === s, "There are not exactly as many question lists as there are sections.");

  var q = $("input[type=hidden][value=Question]").length;
  this.test(v.split("          - !ruby/object:Question").length-1 === q, "Question count doesn’t match in YAML and DOM.");
  this.test(v.split("            boxes:").length-1 === q, "There are not exactly as many box lists as there are questions.");

  var b = $("input[type=hidden][value=Box]").length;
  this.test(v.split("            - !ruby/object:Box").length-1 === b, "Box count doesn’t match in YAML and DOM.");

  // (un)genderizing
  this.loadTestForm();
  this.test(function() { $(".question .language a").first().click() }, "Genderizing text box did not work.");
  this.test(function() { $(".question .language a").first().click() }, "Un-Genderizing text box did not work. (depends on genderizing it first, so may want to check that first)");
  this.checkForNoOps("Genderizing and then un-genderizing is not a no-op.");

  // (un)translating
  this.loadTestForm();
  this.test(function() {$F().getDomObjFromPath("/intro").next().click() }, "Translating text box did not work.");
  this.test(function() { $F().getDomObjFromPath("/intro").children("a").click() }, "Un-Translating text box did not work. (depends on translating it first, so may want to check that first)");
  this.checkForNoOps("Translating and then un-translating is not a no-op.");
};

/* Checks that the current state of the DOM is equal to the original
 * form when converting the DOM to YAML. Effectively checks that the
 * operations so far have yielded nothing. */
FormEditor.prototype.checkForNoOps = function(message) {
  this.dom2yaml();
  this.test(window.formEditorTestForm === $("#form_content").val(), message);
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
  $("#form_content").val(window.formEditorTestForm);
  this.loadFormFromTextbox();
  // overwrite default values that are not true for the test form
  this.languages = [":en", ":de"];
};
