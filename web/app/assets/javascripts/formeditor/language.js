/* Provides all functions necessary to deal with languages/translations
 * in the form. */


/* @public
 * Sets the languages available in this form. It updates the global lang
 * variable to which the create functions refer when they need to know
 * the languages. If there are existing fields it updates them by adding
 * or removing the locales.
 *
 * @param  array (or space-separated string) with two letter lang codes
 * @param  set to true, if this is an automated request. It will not
 *         warn about deletions or invalid data then. */
FormEditor.prototype.setLanguages = function(langs, automated) {
  // get languages from default text box unless given. It is assumed that
  // this is a user action, therefore warn if removing languages.
  var automated = automated || false;
  if(!$.isArray(langs))
    langs = $.trim(langs).split(/\s+/);

  // check input is valid
  var newLangs = [];
  for(var id in langs) {
    if(!langs[id].match(/^:?[a-z][a-z]$/)) {
      alert("Language code may only consist of two letters, optionally prepending a colon. E.g. :en, de. Given was: \""+langs[id]+"\"");
      return false;
    }
    newLangs.push(langs[id].length == 2 ? ":" + langs[id] : langs[id]);
  }

  // warn when removing langs
  var removedLangs = $(this.getLanguagesFromDom()).not(langs);
  if(!automated) {
    var rls = Array.prototype.join.call(removedLangs, ", ");
    var strng = "You are about to remove these language(s): "+rls+". Continue?";
    if(removedLangs.length > 0 && !confirm(strng))
      return false; // stop, because user doesn’t want to remove langs
  }

  if(!automated)
    this.addUndoStep("changing languages to: " + newLangs.join(", "));

  this.languages = newLangs;

  $("#availableLanguages").val(this.languages.join(" ").replace(/:/g, ""));

  // don't do removals/inserts on automated updates. These should only
  // occur once at the start and all fields should already sport the
  // correct languages.
  if(automated)
    return;

  // find translation groups
  $(".language").parent().each(function(ind, transGroup) {
    var path = $(transGroup).attr("id");
    var isTextArea = $(transGroup).find("textarea").length > 0;
    var l = newLangs.slice();
    $(transGroup).children(".language").each(function(ind, langGroup) {
      var lang = $(langGroup).children("span, label").html();
      var index = l.indexOf(lang);
      if(index >= 0) {
        l.splice(index, 1); // ack language is available in dom
      } else {
        $(langGroup).remove(); // remove superfluous lang
      }
    });
    // add missing languages to dom
    $.each(l, function(ind, lang) {
      $F().setPath($F().data, path + "/" + lang, isTextArea ? [] : "");
      $F().generatedHtml = "";
      if(isTextArea)
        $F().createLangTextArea(path, lang);
      else
        $F().createLangTextBox(path, lang);
      $(transGroup).append($F().generatedHtml);
    });
  });
}


/* @public
 * Opens a popup and asks the user which languages the form should
 * support. Considers the already existing ones and applies the user’s
 * changes if the dialog is not aborted. */
FormEditor.prototype.setLanguagesPopup = function() {
  var dat = prompt("Enter languages this form should support. Use two-letter lang codes and separate them by spaces.", $("#availableLanguages").val());
  if(!dat || dat == $("#availableLanguages").val()) return;
  this.setLanguages(dat);
};


/* @public
 * Retrieves languages currently available in the DOM /without/ looking
 * at the global variable. In other words, it find the languages which
 * are actually displayed.
 * @returns array of two-letter lang codes without leading colon */
FormEditor.prototype.getLanguagesFromDom = function() {
  // languages may either be defined in a heading (when genderized)
  // or a label. Collect all possible occurences and assert only valid
  // language codes have been gathered.
  var l = $(".language").children("span, label").map(function(ind, elm) {
    return $(elm).html();
  });
  l = $.unique(l);
  for(var i in l) {
    this.assert(l[i].match(/^:[a-z][a-z]$/)," Language Code must be in the :en format. Given lang: "+l[i]);
    l[i] = l[i].slice(1,3); // cut off colon
  }
  return l;
};


/* @public
 * Translates a given path. It therefore updates the data object from
 * the current DOM. This way the common functions to generate the text
 * boxes and action links may be used.
 * @param caller  The element which issues the call. Required if the
 *                un-translated text box should be replaced with the
 *                new version. Will replace the caller’s parent with
 *                the new textbox. Tailored for the default links. */
FormEditor.prototype.translatePath = function(caller) {
  var path = $(caller).prev().attr('id');
  this.addUndoStep("translating " + path);

  this.updateDataFromDom();

  var isTextArea = $(caller).parent().find("textarea").length > 0;

  // generate new object
  var oldText = "";
  try { // it may not exist, i.e. for empty boxes
    oldText = this.getPath(path);
  } catch(e) {}
  var translated = { };
  $.each(this.languages, function(i, lang) {
    $F().assert(lang.length === 3, "Language Code doesn’t look as expected: " + lang);
    translated[lang] = isTextArea && !$.isArray(oldText) ? oldText.split("\n") : oldText;
  });

  // inject new object
  this.setPath(this.data, path, translated);

  // update dom
  this.generatedHtml = "";
  if(isTextArea)
    this.createTranslateableTextArea(path);
  else
    this.createTranslateableTextBox(path);
  var c = $(this.generatedHtml);
  $(caller).parent().replaceWith(c);
  if(isTextArea) c.find("textarea").autosize();
};

/* @public
 * Works just like translatePath, but the other way round. See there
 * for details. */
FormEditor.prototype.untranslatePath = function(caller) {
  var path = $(caller).parent().attr('id');
  this.addUndoStep("un-translating " + path);

  this.updateDataFromDom();

  // Try to get the English text first, if available. If it isn’t,
  // simply get the first string available.
  var oldText = "";
  try {
   oldText = this.getPath(path + "/:en");
  } catch(e) {
    try {
      oldText = this.getAnyElement(this.getPath(path));
      if(oldText == null) oldText = "";
    } catch(e) {}
  }

  var isTextArea = $(caller).parent().find("textarea").length > 0;
  if(isTextArea && !$.isArray(oldText)) oldText = oldText.split("\n")

  // inject new object
  this.setPath(this.data, path, oldText);
  this.generatedHtml = "";
  if(isTextArea)
    this.createTranslateableTextArea(path);
  else
    this.createTranslateableTextBox(path);
  var c = $(this.generatedHtml);
  $(caller).closest(".heading").replaceWith(c);
  if(isTextArea) c.find("textarea").autosize();
};

/* @public
 * HTML Helper that creates a textbox which may be translated (or
 * already is). Determines all values by reading the from FromEditor’s
 * data variable. Appends to global HTML storage variable
 * (generatedHtml) */
FormEditor.prototype.createTranslateableTextBox = function(path) {
  var lang = [];
  var texts = this.getPath(path);

  if(typeof(texts) == "string") {
    this.openGroup();
    this.createTextBox(path, path.split("/").pop());
    this.createActionLink("$F().translatePath(this)", "Translate »");
    this.closeGroup();
  } else {
    this.createHeading(path);
    if(!this.translationsHaveGendering(texts))
      this.createActionLink("$F().untranslatePath(this)", "« Unify (no localization)");
    for(var lang in texts) {
      this.assert(lang.match(/^:[a-z][a-z]$/), "Language Code must be in the :en format. Given lang: "+lang);
      if(typeof(texts[lang] ) == "string") {
        this.createLangTextBox(path, lang);
      } else {
        this.createLangTextBoxGenderized(path, lang);
      }
    }
    this.closeHeading();
  }
};


/* @private
 * @returns true if at least one of the given translations has gendering */
FormEditor.prototype.translationsHaveGendering = function(texts) {
  for(var lang in texts) {
    if(typeof(texts[lang]) != "string")
      return true;
  }
  return false;
};
