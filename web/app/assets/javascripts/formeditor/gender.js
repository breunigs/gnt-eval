

FormEditor.prototype.genderizePath = function(path, caller) {
  this.updateDataFromDom();
  this.addUndoStep("genderizing " + path);

  // generate new object
  var oldText = this.getPath(path);
  var genderized = { ":male": oldText, ":female": oldText, ":both": oldText};

  // inject new object
  this.setPath(this.data, path, genderized);

  // update dom
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).closest(".heading:not(.language)").replaceWith(this.generatedHtml);
};

FormEditor.prototype.ungenderizePath = function(path, caller) {
  this.addUndoStep("un-gendering " + path);
  this.updateDataFromDom();

  var oldText = this.getPath(path + "/:both");
  // inject new object
  this.setPath(this.data, path, oldText);
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).closest(".heading:not(.language)").replaceWith(this.generatedHtml);
};
