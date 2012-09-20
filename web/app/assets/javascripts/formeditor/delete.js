/* deleting works by simply removing the offending elements from DOM.
 * IDs are not modified, so there may be gaps. Those are later ignored
 * when generating the YAML from the DOM */

FormEditor.prototype.toggleDeleting = function(enable) {
  enable = enable === undefined || enable === null ? $("#delete").is(":visible") : enable;
  if(enable) {
    $("#delete").hide();
    $(".delete, #cancel-delete").show();
  } else {
    $("#delete").show();
    $(".delete, #cancel-delete").hide();
  }
};

/* @public
 * Deletes page break and attaches its sections to the previous page
 * (break).
 * @param  DOM reference to element that is located within the section
 *         (so the section to be deleted can be identified) */
FormEditor.prototype.deletePageBreak = function(link) {
  var s = $(link).parents(".page");
  var allPages = $(".page");
  var pos = allPages.index(s);
  if(pos == 0) {
    alert("Can’t delete first page break (and don’t need to: it’s only there for data structure purposes but doesn’t really break page here)");
    return;
  }
  this.addUndoStep("deleting page");
  // append sections to previous page
  allPages[pos-1].append(s.children(".section"));
  // remove page
  s.replaceWith("");
  this.checkDuplicateIds();
};

/* @public
 * Deletes section and all its questions.
 * @param  DOM reference to element that is located within the section
 *         (so the section to be deleted can be identified) */
FormEditor.prototype.deleteSection = function(link) {
  var s = $(link).parents(".section");
  this.addUndoStep("deleting section " + s.children("h5").data("title") || "");
  s.replaceWith("");
};

/* @public
 * Deletes question.
 * @param  DOM reference to element that is located within the question
 *         (so the question to be deleted can be identified) */
FormEditor.prototype.deleteQuestion = function(link) {
  var q = $(link).parents(".question");
  this.addUndoStep("deleting question " + q.children("h6").data("db-column") || "");
  q.replaceWith("");
};

/* @public
 * Deletes last (check)box of question.
 * @param  DOM reference to link which issued this request. The link
 *         must be exactly one level down from the box groups, i.e
 *           box
 *           box
 *           group > link
 *         otherwise the box will not be found. */
FormEditor.prototype.deleteLastBox = function(link) {
  if($(link).parent().siblings("input[type=hidden][value=Box]").length <= 2) {
    alert("We strongly believe in freedom of choice and therefore cannot allow you to remove more boxes.");
    return;
  }
  this.addUndoStep("deleting box in " + $(link).parents(".indent").attr("id"));
  elms = $(link).parent().prevUntil("input[type=hidden][value=Box]");
  elms.push(elms.prev());
  elms.replaceWith();
};
