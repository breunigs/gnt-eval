/* Implements functions that allow duplicating sections and questions.
 * It works by copying the DOM of that element and adjusting the IDs
 * for that question/section to an unused one. */

/* @public
 * Shows/hides the duplication buttons on sections/questions.
 * @param enable  if the buttons should be shown/hidden */
FormEditor.prototype.toggleDuplicating = function(enable) {
  enable = enable === undefined || enable === null ? $("#duplicate").is(":visible") : enable;
  if(enable) {
    $("#duplicate").hide();
    $(".duplicate, #cancel-duplicate").show();
  } else {
    $("#duplicate").show();
    $(".duplicate, #cancel-duplicate").hide();
  }
};

/* @public
 * Duplicates Question.
 * @param link   DOM reference to an element inside the question that
 *        should be duplicated */
FormEditor.prototype.duplicateQuestion = function(link) {
  var q = $(link).parents(".question");
  this.addUndoStep("duplicating question " + q.children("h6").data("db-column"));
  this.duplicate(q, "Question", "questions");
};

/* @public
 * Duplicates Section.
 * @param link   DOM reference to an element inside the section that
 *        should be duplicated */
FormEditor.prototype.duplicateSection = function(link) {
  var s = $(link).parents(".section");
  this.addUndoStep("duplicating section " + s.children("h5").data("title"));
  this.duplicate(s, "Section", "sections");
};

/* @private
 * Handles copying the DOM element as well as replacing the old IDs with
 * unused ones.
 * @param  DOM element which should be copied
 * @param  Type/AbstractForm Class of equivalent of DOM element being
 *         copied. Required to determine correct path from the hidden
 *         element (…/rubyobject).
 * @param  Name of the part in the path that preceeds the n-th question
 *         or section. Usually multiple and lower-case of type. E.g.
 *         /pages/0/sections/1/questions/2/ → "sections" if a section
 *         is to be duplicated */
FormEditor.prototype.duplicate = function(elm, type, pathGroup) {
  var r = new RegExp("/" + pathGroup + "/([0-9]+)/");

  // find new, not yet used id
  var lastPath = elm.parent().find("[type=hidden][value="+type+"][id^='/']").last().attr("id").match(r),
      oldPath = "/" + pathGroup + "/" + lastPath[1] + "/",
      pos = parseInt(lastPath[1])+1;
  while(true) {
    newPath = "/" + pathGroup + "/" + pos + "/";
    var check = document.getElementById(lastPath[0].replace(oldPath, newPath));
    if(check === null) break;
    pos++;
  }

  // clone and update id/for attributes
  var newElm = elm.clone();
  newElm.find("[id^='/']").each(function(pos, elm) {
    $(elm).attr("id", $(elm).attr("id").replace(r, newPath));
  });
  newElm.find("[for^='/']").each(function(pos, elm) {
    $(elm).attr("for", $(elm).attr("for").replace(r, newPath));
  });

  newElm.insertAfter(elm);
  this.checkDuplicateIds();
};
