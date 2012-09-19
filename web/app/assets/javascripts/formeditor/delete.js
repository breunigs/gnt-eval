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

FormEditor.prototype.deleteSection = function(link) {
  var s = $(link).parents(".section");
  this.addUndoStep("deleting section " + s.children("h5").data("title"));
  s.replaceWith("");
};

FormEditor.prototype.deleteQuestion = function(link) {
  var q = $(link).parents(".question");
  this.addUndoStep("deleting question " + q.children("h6").data("db-column"));
  q.replaceWith("");
};

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
