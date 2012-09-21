
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



FormEditor.prototype.duplicateQuestion = function(link) {
  var q = $(link).parents(".question");
  this.addUndoStep("duplicating question " + q.children("h6").data("db-column"));
  this.duplicate(q, "Question", "questions");
};

FormEditor.prototype.duplicateSection = function(link) {
  var s = $(link).parents(".section");
  this.addUndoStep("duplicating section " + s.children("h5").data("title"));
  this.duplicate(s, "Section", "sections");
};

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
