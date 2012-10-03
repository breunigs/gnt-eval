/* This fail hosts all tests and related helper functions. It is only
 * loaded in rails development mode. The tests are not run by default,
 * but can be issued using $F().runTests(). You can also comment in the
 * block below to run them on each reload. A custom form is used for the
 * tests, it is specified at the bottom of this file. */


$(document).ready(function() {
  //$F().runTests();
});


/* Runs all available tests. */
FormEditor.prototype.runTests = function() {
  // prevent submission everywhere
  $("form").attr("action", "");

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
  l = $("input[type=hidden][value=Section]");
  $F().test(l.length === 1, "There should be only one (hidden) section header, but "+l.length+" have been found.");
  $F().test(function() { newSection.click() }, "Creating a new section didn’t work.");
  l = $("input[type=hidden][value=Section]");
  $F().test(l.length === 2, "(After adding section) There should now be two (hidden) section headers, but "+l.length+" have been found.");
  $F().test(function() { $(".section > .header > .delete").last().click() }, "Deleting a section didn’t work.");
  $F().checkForNoOps("Adding and deleting a section isn’t no-op.");
  l = $("input[type=hidden][value=Section]");
  $F().test(l.length === 1, "(After deleting section) There should now be only one (hidden) section header, but "+l.length+" have been found.");

  // Question basics: adding, removing
  $F().loadTestForm();
  var newQuestion = $F().findLinksByText("#form_editor", "Create New Question");
  $F().test(newQuestion.length === 1, "There should be only one new question link, but "+newQuestion.length+" have been found.");
  l = $("input[type=hidden][value=Question]");
  $F().test(l.length === 5, "There should be five (hidden) question headers, but "+l.length+" have been found.");
  $F().test(function() { newQuestion.click() }, "Creating a new question didn’t work.");
  l = $("input[type=hidden][value=Question]");
  $F().test(l.length === 6, "(After adding question) There should now be six (hidden) question headers, but "+l.length+" have been found.");
  $F().test(function() { $(".question > .header > .delete").last().click() }, "Deleting a question didn’t work.");
  $F().checkForNoOps("Adding and deleting a question isn’t no-op.");
  l = $("input[type=hidden][value=Question]");
  $F().test(l.length === 5, "(After deleting question) There should now again be five (hidden) question headers, but "+l.length+" have been found.");

  // Undo/Redo
  $F().loadTestForm();
  $F().test(function() { $F().findLinksByText("#form_editor", "Create New Question").click(); $("#undo").click(); }, "Undo-ing didn’t work.");
  $F().checkForNoOps("Creating a question and undoing isn’t a no-op.");
  $F().test(this.undoData.length == 0, "There shouldn’t be any undo step, but "+this.undoData.length+"are possible.");
  $F().test(function() { $("#redo").click(); }, "Redo-ing didn’t work.");
  // check typing into field adds undo step
  $("input[id$=column]").first().focus().val("test test").change();
  $F().test(this.undoData.length == 2 /* new quest + value change */, "Changing text didn’t create undo event.");

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
};
