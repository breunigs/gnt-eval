/* This file contains all sorts of generic HTML tools that simplify
 * creating stuff. They append to the global generatedHtml variable
 * and return nothing, without exception */

/* @public
 * Creates a textarea for the given path that may be translated (or
 * already is). Textareas may not be genderized and they therefore do
 * not display the genderize link. */
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


/* @public
 * Creates text BOX which is neither translatable nor genderizable. The
 * value for the box may be a string (or similar, but not an array); it
 * is automatically retrieved from the global data variable.
 * @param  path that identifies this field. Must exist in the data
 *         variable because the value is retrieved from there.
 * @param  label, i.e. how the text field will be named for the user
 * @param  set to true, if the text box should be enclosed in an
 *         extra DIV tag. If set to false, only label+input tags are
 *         inserted.
 * @param  If group is set to true, you can specify space-separated
 *         CSS classes for that group/DIV-tag. */
FormEditor.prototype.createTextBox = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");

  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<input type="text" id="'+path+'" value="'+this.getPath(path)+'"/>');
  if(group) this.closeGroup();
};

/* @public
 * Creates text AREA which is neither translatable nor genderizable. The
 * value for the area must be an array of strings (or similar); it
 * is automatically retrieved from the global data variable.
 *
 * The parameters are the same as for createTextBox. See there for more.
 */
FormEditor.prototype.createTextArea = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");
  this.assert($.isArray(this.getPath(path)), "Textareas can only display arrays.");


  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<textarea wrap="off" id="'+path+'">'+this.getPath(path).join("\n")+'</textarea>');
  if(group) this.closeGroup();
};


/* @public
 * Creates text box which is tailored for numeric values (jQuery magic
 * attaches to them and only allows numerical input).
 *
 * The parameters are the same as for createTextBox. See there for more.
 */
FormEditor.prototype.createNumericBox = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");

  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<input pattern="[0-9]*" type="numeric" id="'+path+'" value="'+this.getPath(path)+'"/>');
  if(group) this.closeGroup();
};

/* @public
 * Creates check box. The state is retrieved from the global data
 * variable.
 *
 * The parameters are the same as for createTextBox. See there for more.
 */
FormEditor.prototype.createCheckBox = function(path, label, group, cssClasses) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");

  if(group) this.openGroup(cssClasses);
  var c = this.getPath(path) ? 'checked="checked"' : '';
  this.append('<label for="'+path+'">'+label+'</label>');
  this.append('<input id="'+path+'" type="checkbox" value="true" '+c+'/>');
  if(group) this.closeGroup();
};

/* @public
 * Creates a select box for a given path. The selectable options need to
 * be provided, but pre-selecting the correct option is done
 * automatically by reading the global data variable.
 *
 * @param  path that identifies this field. Must exist in the data
 *         variable because the value is retrieved from there.
 * @param  label, i.e. how the text field will be named for the user
 * @param  array of options to display in this group. Must not be empty.
 * @param  set to true, if the text box should be enclosed in an
 *         extra DIV tag. If set to false, only label+input tags are
 *         inserted.
 * @param  If group is set to true, you can specify space-separated
 *         CSS classes for that group/DIV-tag.
 * @param  Give a name of action that should be executed when the
 *         value of the select box changes. Needs to be available in the
 *         FormEditor. Will be handed the select box that */
FormEditor.prototype.createSelectBox = function(path, label, list, group, cssClasses, jsAction) {
  this.assert(path !== undefined, "Given path is invalid.");
  this.assert(label !== undefined, "Given label is invalid.");
  this.assert(list !== undefined && list.length >0, "Given list must not be empty.");

  var value = this.getPath(path);

  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+path+'">'+label+'</label>');
  var act = (jsAction ? 'onchange="$F().'+jsAction+'(this)"' : '');
  this.append('<select id="'+path+'" '+act+'>');
  this.append(this.createOptionsForSelect(list, value));
  this.append('</select>');
  if(group) this.closeGroup();
};

/* @private
 * Helper function that generates a list of option-tags from an array.
 * @param list of values that should be turned into options
 * @param value which should be pre-selected */
FormEditor.prototype.createOptionsForSelect = function(list, selected) {
  var s = "";
  for(ind in list) {
    var sel = (list[ind] == selected ? ' selected="selected"' : '');
    s += '<option value="'+list[ind]+'"'+sel+'>'+list[ind]+'</option>';
  }
  return s;
};

/* @public
 * Creates a hidden box that can store values but is not visible to
 * the user.
 * @param path which identifies this field. It is not checked and must
 *        not exist in the data attribute. Advantage is that you can
 *        insert control information that is, e.g. required by
 *        JSON 2 Ruby YAML.
 * @param value to set the field to. */
FormEditor.prototype.createHiddenBox = function(path, value) {
  this.append('<input type="hidden" id="'+path+'" value="'+value+'"/>');
};


/* @public
 * Inserts a heading into generatedHtml (but does not close it). Title
 * for it is determined by the path.
 * @param  path of which to create the heading for. It must not actually
 *         exist, the title is determined by the string value only.
 * @param  space separated CSS classes to add to the element */
FormEditor.prototype.createHeading = function(path, cssClasses) {
  var last = path.split("/").pop();
  cssClasses = cssClasses ? cssClasses : "";
  this.append('<div class="heading '+cssClasses+'"><span>'+last+'</span><div class="indent" id="'+path+'">');
};

/* @public
 * closes heading opened by createHeading */
FormEditor.prototype.closeHeading = function(path) {
  this.append("</div></div>");
};

/* @public
 * Creates link with the given JS action in an onclick event. Handles
 * all the escaping so that the resulting HTML code is valid.
 * @param  JS action to be executed on click
 * @param  link text/content
 * @param  space separated CSS classes */
FormEditor.prototype.createActionLink = function(action, name, cssClasses) {
  cssClasses = cssClasses || "";
  if(action.indexOf('"') >= 0)
    action = "eval(unescape('"+escape(action)+"'))"; // work around quotation marks
  this.append('<a class="'+cssClasses+'" onclick="'+action+'">'+name+'</a>');
};

/* @public
 * Opens a group (inserts extra tags).
 * @params space separated CSS classes to apply to the group
 * @params (optional) tag to use for the group. If omitted, defaults to
 *         DIV. */
FormEditor.prototype.openGroup = function(cssClasses, tag) {
  tag = tag || "div"
  this.groupTagStack.push(tag);
  cssClasses = cssClasses ? cssClasses : "";
  this.append('<'+tag+' class="'+cssClasses+'">');
};

/* @public
 * Closes previously opened group. Automatically chooses the correct
 * tag. */
FormEditor.prototype.closeGroup = function() {
  this.assert(this.groupTagStack.length > 0, "Trying to close group which has not been opened.");
  this.append("</"+ this.groupTagStack.pop() +">");
};


/* @private
 * Creates a translated text BOX for a given locale and path. Also
 * generates a genderize link */
FormEditor.prototype.createLangTextBox = function(path, lang) {
  var path = path+"/"+lang;
  this.openGroup("language");
  this.createTextBox(path, lang);
  this.createActionLink("$F().genderizePath(\""+path+"\", this)", "Genderize »", "genderize");
  this.closeGroup();
};

/* @private
 * Creates a translated text AREA for a given locale and path. Also
 * generates a genderize link */
FormEditor.prototype.createLangTextArea = function(path, lang) {
  var path = path+"/"+lang;
  this.openGroup("language");
  this.createTextArea(path, lang);
  this.closeGroup();
};

/* @private
 * Create a translated and genderized text box for a given locale and
 * path. Offers an un-genderize link. */
FormEditor.prototype.createLangTextBoxGenderized = function(path, lang) {
  var path = path+"/"+lang;
  this.createHeading(path, "language");
  this.createActionLink("$F().ungenderizePath(\""+path+"\", this)", "« no gender");
  this.createTextBox(path + "/:both", "neutral", true);
  this.createTextBox(path + "/:female", "female", true);
  this.createTextBox(path + "/:male", "male", true);
  this.closeHeading();
};
