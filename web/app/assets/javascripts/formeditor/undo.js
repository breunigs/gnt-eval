/* contains all functions that allow undo-/redoing changes made to the
 * form.
 *
 * Before a change is commited to the form, it simply stores a copy of
 * the whole form editor in an undo-array. On undo (or redo) the
 * contents are received from the array and replace the current content.
 * The action links (i.e. the ones in the toolbox) are shown/hidden
 * after each undo/redo to match the status of the toolbox.
 *
 * A new undo step may be added using addUndoStep. If it’s necessary to
 * capture the contents before actually adding an undo step, you can use
 * fillUndoTmp and use addUndoStep("asdf", $F().undoTmp()).
 *
 * The title handed in should be lower case, so that "Undo doing this
 * and that" looks like a proper sentence. */


/* @public
 * adds new undo step. Up to 5 steps are stored, after that they are
 * discarded.
 * @param title   starts with lower case. Describes what has been done
 * @param data    #form_editor content, e.g. captured by fillUndoTmp
 *                and stored in undoTmp. If undefined/null, the current
 *                form editor state is stored. */
FormEditor.prototype.addUndoStep = function(title, data) {
  this.log("Adding undo step: " + title);
  $formHasBeenEdited++;
  data = data || $("#form_editor").html();
  this.redoData = new Array();
  this.undoData.push([title, data]);
  this.undoData = this.undoData.slice(-5);
  this.updateUndoRedoLinks();
};


/* @public
 * Store current form editor state in buffer before actually committing
 * an undo step. */
FormEditor.prototype.fillUndoTmp = function() {
  this.undoTmp = $("#form_editor").html();
};


/* @public
 * Matches action links in the form editor to the state of the buttons
 * in the toolbox */
FormEditor.prototype.updateActionLinksToMatchTools = function() {
  this.toggleSorting(!$("#sort").is(":visible"));
  this.toggleDeleting(!$("#delete").is(":visible"));
  this.toggleDuplicating(!$("#duplicate").is(":visible"));
};


/* @public
 * Undoes last step. */
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


/* @public
 * Redo step. */
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


/* @private
 * En-/disables undo/redo buttons depending on available data. */
FormEditor.prototype.updateUndoRedoLinks = function() {
  $("#undo").toggleClass("disabled", this.undoData.length == 0);
  $("#redo").toggleClass("disabled", this.redoData.length == 0);
  $("#undo span").html(this.undoData.length == 0 ? "" : this.undoData.slice(-1)[0][0]);
  $("#redo span").html(this.redoData.length == 0 ? "" : this.redoData.slice(-1)[0][0]);
};
