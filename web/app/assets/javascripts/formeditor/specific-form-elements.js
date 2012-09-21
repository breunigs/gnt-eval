/* this file contains creators for specific form elements that may only
 * ever be useful once. It also hosts all functions that allow creating
 * a new page, question and so on. */

/* @public
 * Creates “hide answers” checkbox for given question and path.
 * @param question   child-object from global data variable
 * @param path */
FormEditor.prototype.createHideAnswersBox = function (question, path) {
  question["hide_answers"] = question["hide_answers"] || false;
  var hidden = question["type"] != "Single" ? "hidden" : "";
  this.createCheckBox(path + "/hide_answers", "hide_answers", true, hidden);
};

/* @public
 * Creates “last is textbox” numeric field for given question and path.
 * @param question   child-object from global data variable
 * @param path */
FormEditor.prototype.createLastIsTextBox = function (question, path) {
  question["last_is_textbox"] = question["last_is_textbox"] || 0;
  var hidden = question["type"] != "Single" ? "hidden" : "";
  this.createNumericBox(path + "/last_is_textbox", "last_is_textbox", true, hidden);
};

/* @public
 * Creates “height” (for comment questions) numeric field for given
 * question and path.
 * @param question   child-object from global data variable
 * @param path */
FormEditor.prototype.createHeightBox = function (question, path) {
  question["height"] = question["height"] || 300;
  var hidden = question["type"] != "Text" ? "hidden" : "";
  this.createNumericBox(path + "/height", "height", true, hidden);
};

/* @public
 * Creates elements necessary for an AbstractForm Box, i.e. the ones
 * which get later printed onto paper. Since these boxes only have a
 * text field to describe them, this function only creates that text
 * box (and now the <input> text box meant)
 * @params path */
FormEditor.prototype.createUserBox = function(path) {
  this.createHiddenBox(path + "/rubyobject", "Box");
  this.createTranslateableTextBox(path + "/text");
}



/* @public
 * Inserts an additional page break at the end of the form. */
FormEditor.prototype.createAdditionalPage = function() {
  this.addUndoStep("Create New Page");
  this.updateDataFromDom();

  var p = {};
  $.each(ATTRIBUTES["Page"], function(ind, attr) {
    p[attr] = "";
  });

  var path = "/pages/",
      pos  = $(".page").length;
  // ensure the chosen position does not yet exist in DOM. Deleting
  // and duplicating does not ensure the IDs are in order without gaps.
  while(document.getElementById(path + pos) !== null) { pos++; }
  path += pos;

  this.generatedHtml = "";

  this.setPath(this.data, path, p);
  this.parsePage(p, path);
  $(this.generatedHtml).insertAfter($(".page").last());

  this.checkDuplicateIds();
  this.updateActionLinksToMatchTools();
};


/* @public
 * Creates an additional section which is inserted at the end of the
 * current page. Latter is determined by the DOM reference given.
 * @param link that called this function. Must be a child of the page
 *        the new section should be appended to. */
FormEditor.prototype.createAdditionalSection = function(link) {
  this.assert(link !== undefined, "No link given, unable to determine where to put new section.");
  this.addUndoStep("Create New Section");

  // find path for new section
  var page = $(link).parents(".page");
  var path = page.find("input[type=hidden][value=Page]").attr("id");
  path = path.replace(/\/rubyobject$/, "") + "/sections/";
  var pos = page.find(".section").length;
  // ensure the chosen position does not yet exist in DOM. Deleting
  // and duplicating does not ensure the IDs are in order without gaps.
  while(document.getElementById(path + pos) !== null) { pos++; }
  path += pos;
  this.log("Path for new section: " + path);


  // generate new section and insert it into the data object
  var s = {};
  $.each(ATTRIBUTES["Section"], function(ind, attr) {
    s[attr] = "";
  });
  // need to add it manually here, so it’s available in the path
  s["answers"] = [];
  this.updateDataFromDom();
  this.setPath(this.data, path, s);

  // render and inject into DOM
  this.generatedHtml = "";
  this.parseSection(s, path);
  $(this.generatedHtml).insertBefore($(link).parent());
  this.checkDuplicateIds();

  // new section is created with all tools enabled
  this.updateActionLinksToMatchTools();

  // expand header details for convenience
  this.getDomObjFromPath(path + "/rubyobject").parent().find("h6 .collapse").click();
};

/* @public
 * Creates an additional question which is inserted at the end of the
 * current section. Latter is determined by the DOM reference given.
 * @param link that called this function. Must be a child of the section
 *        the new question should be appended to. */
FormEditor.prototype.createAdditionalQuestion = function(link) {
  this.assert(link !== undefined, "No link given, unable to determine where to put new question.");
  this.addUndoStep("Create New Question");

  // find path for new section
  var sect = $(link).parents(".section");
  var path = sect.find("input[type=hidden][value=Section]").attr("id");
  path = path.replace(/\/rubyobject$/, "") + "/questions/";
  var pos = sect.find(".question").length;
  // ensure the chosen position does not yet exist in DOM. Deleting
  // and duplicating does not ensure the IDs are in order without gaps.
  while(document.getElementById(path + pos) !== null) { pos++; }
  path += pos;
  this.log("Path for new question: " + path);

  // generate new question and insert it into the data object
  // questions don’t have generic attributes because the order matters
  // and special ones are mixed in between. Therefore they are not
  // handled via ATTRIBUTES in the original creation.
  var q = {
    "qtext":           "",
    "db_column":       "",
    "hide_answers":    0,
    "height":          null,
    "repeat_for":      null,
    "last_is_textbox": 0};
  // TODO: replace with proper value once types have been modernized
  q["type"] = "square";
  // use sensible default here
  q["visualizer"] = "histogram";
  // start question with two empty boxes
  var box = {"rubyobject": "Box", "text": ""};
  q["boxes"] = [box, box];

  this.updateDataFromDom();
  this.setPath(this.data, path, q);

  // render and inject into DOM
  this.generatedHtml = "";
  this.parseQuestion(q, path);
  sect.find("ol").append($(this.generatedHtml));
  this.checkDuplicateIds();

  // new question is created with all tools enabled
  this.updateActionLinksToMatchTools();

  // auto expand for convenience
  this.getDomObjFromPath(path + "/rubyobject").parents(".question").find(".collapse").click();
};

/* @public
 * Inserts an additional AbstractForm box (i.e. the ones get printed)
 * after the current boxes.
 * @param link which called this function. Required to determine where
 *        to add the new box. The select rule is rather complicated but
 *        suits the position of the default links. */
FormEditor.prototype.createAdditionalUserBox = function(link) {
  var s = $(link).parent().siblings("input[type=hidden][value=Box]").length;
  if(s >= 14) {
    alert("Not sure if so many boxes are even supported… even if, who is going to read them?!");
    return;
  }
  var bpath = $(link).parents(".indent").attr("id");
  this.addUndoStep("creating new box in " + bpath);
  bpath = bpath + "/" + s;
  this.setPath(this.data, bpath + "/text", "");
  this.generatedHtml = "";
  this.createUserBox(bpath);
  $(this.generatedHtml).insertBefore($(link).parent());
}
