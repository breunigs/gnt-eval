FormEditor.prototype.fillUndoTmp = function() {
  this.undoTmp = $("#form_editor").html();
};


FormEditor.prototype.updateActionLinksToMatchTools = function() {
  this.toggleSorting(!$("#sort").is(":visible"));
  this.toggleDeleting(!$("#delete").is(":visible"));
  this.toggleDuplicating(!$("#duplicate").is(":visible"));
};


FormEditor.prototype.undo = function() {
  if(this.undoData.length==0) {
    this.log("Cannot undo, as undo stack is empty");
    return;
  }
  var step = this.undoData.pop();
  this.redoData.push([step[0], $("#form_editor").html()]);
  $("#form_editor").html(step[1]);
  this.updateUndoRedoLinks();
  this.updateActionLinksToMatchTools();
};

FormEditor.prototype.redo = function() {
  if(this.redoData.length==0) {
    this.log("Cannot redo, as redo stack is empty");
    return;
  }
  var step = this.redoData.pop();
  this.undoData.push([step[0], $("#form_editor").html()]);
  $("#form_editor").html(step[1]);
  this.updateUndoRedoLinks();
  this.updateActionLinksToMatchTools();
};

FormEditor.prototype.updateUndoRedoLinks = function() {
  $("#undo").toggleClass("disabled", this.undoData.length == 0);
  $("#redo").toggleClass("disabled", this.redoData.length == 0);
  $("#undo span").html(this.undoData.length == 0 ? "" : this.undoData.slice(-1)[0][0]);
  $("#redo span").html(this.redoData.length == 0 ? "" : this.redoData.slice(-1)[0][0]);
};


FormEditor.prototype.addUndoStep = function(title, data) {
  this.log("Adding undo step: " + title);
  $formHasBeenEdited++;
  data = data || $("#form_editor").html();
  this.redoData = new Array();
  this.undoData.push([title, data]);
  this.undoData = this.undoData.slice(-5);
  this.updateUndoRedoLinks();
};
