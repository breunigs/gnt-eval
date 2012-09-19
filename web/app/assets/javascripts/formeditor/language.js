
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
      var sis = FormEditor.getInstance();
      sis.setPath(sis.data, path + "/" + lang, isTextArea ? [] : "");
      sis.generatedHtml = "";
      if(isTextArea)
        sis.createLangTextArea(path, lang);
      else
        sis.createLangTextBox(path, lang);
      $(transGroup).append(sis.generatedHtml);
    });
  });
}



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
      var sis = FormEditor.getInstance();
      sis.setPath(sis.data, path + "/" + lang, isTextArea ? [] : "");
      sis.generatedHtml = "";
      if(isTextArea)
        sis.createLangTextArea(path, lang);
      else
        sis.createLangTextBox(path, lang);
      $(transGroup).append(sis.generatedHtml);
    });
  });
}



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


FormEditor.prototype.translatePath = function(path, caller) {
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
    translated[lang] = isTextArea ? oldText.split("\n") : oldText;
  });

  // inject new object
  this.setPath(this.data, path, translated);

  // update dom
  this.generatedHtml = "";
  if(isTextArea)
    this.createTranslateableTextArea(path);
  else
    this.createTranslateableTextBox(path);
  $(caller).parent().replaceWith(this.generatedHtml);
};

FormEditor.prototype.untranslatePath = function(path, caller) {
  this.addUndoStep("un-translating " + path);

  this.updateDataFromDom();

  // Try to get the English text first, if available. If it isn’t,
  // simply get the first string available.
  var oldText = "";
  try {
   oldText = this.getPath(path + "/:en");
  } catch(e) {
    try {
      oldText = this.getAttributeByIndex(this.getPath(path), 0);
      if(oldText == null) oldText = "";
    } catch(e) {}
  }

  var isTextArea = $(caller).parent().find("textarea").length > 0;

  // inject new object
  this.setPath(this.data, path, isTextArea ? oldText.split("\n") : oldText);
  this.generatedHtml = "";
  if(isTextArea)
    this.createTranslateableTextArea(path);
  else
    this.createTranslateableTextBox(path);
  $(caller).closest(".heading").replaceWith(this.generatedHtml);
};

FormEditor.prototype.createTranslateableTextBox = function(path) {
  var lang = [];
  var texts = this.getPath(path);

  if(typeof(texts) == "string") {
    this.openGroup();
    this.createTextBox(path, path.split("/").pop());
    this.createActionLink("$F().translatePath(\""+path+"\", this)", "Translate »");
    this.closeGroup();
  } else {
    this.createHeading(path);
    if(!this.translationsHaveGendering(texts))
      this.createActionLink("$F().untranslatePath(\""+path+"\", this)", "« Unify (no localization)");
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


FormEditor.prototype.setLanguagesPopup = function() {
  var dat = prompt("Enter languages this form should support. Use two-letter lang codes and separate them by spaces.", $("#availableLanguages").val());
  if(!dat || dat == $("#availableLanguages").val()) return;
  this.setLanguages(dat);
};

// Checks if at least one of the given translations has gendering
FormEditor.prototype.translationsHaveGendering = function(texts) {
  for(var lang in texts) {
    if(typeof(texts[lang]) != "string")
      return true;
  }
  return false;
};
