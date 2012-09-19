FormEditor.prototype.createHideAnswersBox = function (question, path) {
  question["hide_answers"] = question["hide_answers"] || false;
  var hidden = question["type"] != "Single" ? "hidden" : "";
  this.createCheckBox(path + "/hide_answers", "hide_answers", true, hidden);
};

FormEditor.prototype.createLastIsTextBox = function (question, path) {
  question["last_is_textbox"] = question["last_is_textbox"] || 0;
  var hidden = question["type"] != "Single" ? "hidden" : "";
  this.createNumericBox(path + "/last_is_textbox", "last_is_textbox", true, hidden);
};

FormEditor.prototype.createHeightBox = function (question, path) {
  question["height"] = question["height"] || 300;
  var hidden = question["type"] != "Text" ? "hidden" : "";
  this.createNumericBox(path + "/height", "height", true, hidden);
};

FormEditor.prototype.createUserBox = function(path) {
  this.createHiddenBox(path + "/rubyobject", "Box");
  this.createTranslateableTextBox(path + "/text");
}

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
