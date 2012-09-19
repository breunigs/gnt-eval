

// does not support genderization. Creates a textarea instead to allow
// easy creation of an array.
FormEditor.prototype.createTranslateableTextArea = function(path) {
  var lang = [];
  var texts = this.getPath(path);

  this.openGroup();
  if($.isArray(texts)) {
    this.openGroup();
    this.createTextArea(path, path.split("/").pop());
    this.createActionLink("$F().translatePath(\""+path+"\", this)", "Translate »");
    this.closeGroup();
  } else {
    this.createHeading(path);
    this.createActionLink("$F().untranslatePath(\""+path+"\", this)", "« Unify (no localization)");
    for(var lang in texts) {
      this.assert(lang.match(/^:[a-z][a-z]$/), "Language Code must be in the :en format. Given lang: "+lang);
      this.assert($.isArray(texts[lang]), "Text Areas only support arrays as input, but something else was given.");
      this.createLangTextArea(path, lang);
    }
    this.closeHeading();
  }
  this.closeGroup();
};


FormEditor.prototype.createLangTextBox = function(path, lang) {
  var path = path+"/"+lang;
  this.openGroup("language");
  this.createTextBox(path, lang);
  this.createActionLink("$F().genderizePath(\""+path+"\", this)", "Genderize »", "genderize");
  this.closeGroup();
};

FormEditor.prototype.createLangTextArea = function(path, lang) {
  var path = path+"/"+lang;
  this.openGroup("language");
  this.createTextArea(path, lang);
  this.closeGroup();
};

FormEditor.prototype.createLangTextBoxGenderized = function(path, lang) {
  var path = path+"/"+lang;
  this.createHeading(path, "language");
  this.createActionLink("$F().ungenderizePath(\""+path+"\", this)", "« no gender");
  this.createTextBox(path + "/:both", "neutral", true);
  this.createTextBox(path + "/:female", "female", true);
  this.createTextBox(path + "/:male", "male", true);
  this.closeHeading();
};

// creates a textbox for a single value that is not translatable.
FormEditor.prototype.createTextBox = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");

  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<input type="text" id="'+path+'" value="'+this.getPath(path)+'"/>');
  if(group) this.closeGroup();
};

FormEditor.prototype.createTextArea = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");
  this.assert($.isArray(this.getPath(path)), "Textareas can only display arrays.");


  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<textarea wrap="off" id="'+path+'">'+this.getPath(path).join("\n")+'</textarea>');
  if(group) this.closeGroup();
};


FormEditor.prototype.createNumericBox = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");

  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<input pattern="[0-9]*" type="numeric" id="'+path+'" value="'+this.getPath(path)+'"/>');
  if(group) this.closeGroup();
};

FormEditor.prototype.createHiddenBox = function(path, value) {
  this.append('<input type="hidden" id="'+path+'" value="'+value+'"/>');
};

FormEditor.prototype.createCheckBox = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");

  if(group) this.openGroup(cssClasses);
  var c = this.getPath(path) ? 'checked="checked"' : '';
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<input id="'+path+'" type="checkbox" value="true" '+c+'/>');
  if(group) this.closeGroup();
};

FormEditor.prototype.createSelectBox = function(path, label, list, group, cssClasses, jsAction) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");
  this.assert(list !== undefined && list.length >0, "Given list must not be empty.");

  var value = this.getPath(path);

  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  var act = (jsAction ? 'onchange="FormEditor.prototype.'+jsAction+'(this)"' : '');
  this.append('<select id="'+path+'" '+act+'>');
  this.append(this.createOptionsForSelect(list, value));
  this.append('</select>');
  if(group) this.closeGroup();
};

FormEditor.prototype.createOptionsForSelect = function(list, selected) {
  var s = "";
  for(ind in list) {
    var sel = (list[ind] == selected ? ' selected="selected"' : '');
    s += '<option value="'+list[ind]+'"'+sel+'>'+list[ind]+'</option>';
  }
  return s;
};

FormEditor.prototype.createHeading = function(path, cssClasses) {
  var last = path.split("/").pop();
  cssClasses = cssClasses ? cssClasses : "";
  this.append('<div class="heading '+cssClasses+'"><span>'+last+'</span><div class="indent" id="'+path+'">');
};

FormEditor.prototype.closeHeading = function(path) {
  this.append("</div></div>");
};

FormEditor.prototype.createActionLink = function(action, name, cssClasses) {
  cssClasses = cssClasses || "";
  if(action.indexOf('"') >= 0)
    action = "eval(unescape('"+escape(action)+"'))"; // work around quotation marks
  this.append('<a class="'+cssClasses+'" onclick="'+action+'">'+name+'</a>');
};

FormEditor.prototype.openGroup = function(cssClasses, tag) {
  tag = tag || "div"
  this.groupTagStack.push(tag);
  cssClasses = cssClasses ? cssClasses : "";
  this.append('<'+tag+' class="'+cssClasses+'">');
};

FormEditor.prototype.closeGroup = function() {
  this.assert(this.groupTagStack.length > 0, "Trying to close group which has not been opened.");
  this.append("</"+ this.groupTagStack.pop() +">");
};


FormEditor.prototype.createAvailLangBox = function() {
  var langString = this.languages.join(" ").replace(/:/g, "");
  this.createHiddenBox("availableLanguages", langString);
};
