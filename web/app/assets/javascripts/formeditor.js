$.extend({
  unique : function(anArray) {
   var result = [];
   $.each(anArray, function(i,v){
      if ($.inArray(v, result) == -1) result.push(v);
   });
   return result;
  }
});


function FormEditor() {
  // singleton, via http://stackoverflow.com/a/6876814
  if(arguments.callee.instance)
    return arguments.callee.instance;
  arguments.callee.instance = this;


  this.source = $('#form_content');
  this.root = $('#form_editor');
  this.languages = ["en"];
  this.data = this.getValue();
  this.invalidData = false;
  this.generatedHtml = "";

  this.parseAbstractForm(this.data);
}

FormEditor.getInstance = function() {
  var fe = new FormEditor();
  return fe;
};

FormEditor.prototype.setLanguages = function(langs) {
  // get languages from default text box unless given. It is assumed that
  // this is a user action, therefore warn if removing languages.
  var automated = langs ? true : false;
  if(!automated)
    langs = $.trim($("#availableLanguages").val()).split(/\s+/);

  var removedLangs = $(this.getLanguagesFromDom()).not(langs);

  if(!automated) {
    var rls = Array.prototype.join.call(removedLangs, ", ");
    var strng = "You are about to remove these language(s): "+rls+". Continue?";
    if(removedLangs.length > 0 && !confirm(strng))
      return false; // stop, because user doesn’t want to remove langs
  }

  var newLangs = [];
  for(var id in langs) {
    if(!langs[id].match(/^:?[a-z][a-z]$/)) {
      alert("Language code may only consist of two letters, optionally prepending a colon. E.g. :en, de. Given was: \""+langs[id]+"\"");
      return false;
    }
    newLangs.push(langs[id].length == 2 ? ":" + langs[id] : langs[id]);
  }
  this.languages = newLangs;

  $("#availableLanguages").val(this.languages.join(" ").replace(/:/g, ""));

  // don't do removals/inserts on automated updates. These should only
  // occur once at the start and all fields should already sport the
  // correct languages.
  if(automated)
    return;

  // find translation groups
  $(".language").parent().each(function(ind, transGroup) {
    var path = $(transGroup).attr("title");
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
      sis.setPath(sis.data, path + "/" + lang, "");
      sis.generatedHtml = "";
      sis.createLangTextBox(path, lang);
      $(transGroup).append(sis.generatedHtml);
    });
  });
}

FormEditor.prototype.append = function(content) {
  this.generatedHtml += content + "\n";
};

FormEditor.prototype.getPath = function(path) {
  var l = path.split("/");
  this.assert("" == l.shift(), "Invalid path given. Must start with /. Given: " + path);
  var r = this.data;
  var pathok = "";
  for(var x in l) {
    r = r[l[x]];
    this.assert(r !== undefined, "Invalid path given. Element does not exist. Given path: "+path + "  Path correct for: " + pathok);
    pathok += "/" + l[x];
  }
  return r;
};

FormEditor.prototype.getPathDepth = function(path) {
  return path.split("/").length - 1;
};

FormEditor.prototype.createLanguageControlBox = function() {
  this.openGroup();
  var langString = this.languages.join(" ").replace(/:/g, "");
  this.append('<label for="availableLanguages">Langs</label>');
  this.append('<input type="text" id="availableLanguages" value="'+langString+'">');
  this.createActionLink("FormEditor.getInstance().setLanguages();", "Update Languages");
  this.closeGroup();
};

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


FormEditor.prototype.parseAbstractForm = function(data) {
  var path = "";

  this.assert(data["rubyobject"] == "AbstractForm", "First entry of data is not an AbstractForm. Either the form is broken or the data subset passed is not an AbstractForm.");

  this.createLanguageControlBox();


  this.createTextBox(path + "/db_table", "database table");
  this.append("<br/>");

  for(var x in data) {
    var d = this.data[x];
    if(x.match("rubyobject|pages|db_table$"))
      continue;

    this.assert($.inArray(ATTRIBUTES["AbstractForm"].x), "The given data subset contains an unknown attribute for AbstractForm: " + x + ".");

    this.createTranslateableTextBox(path + "/" + x, x);
  }

  // handle pages here
  for(var x in this.data["pages"]) {
    var page = this.data["pages"][x];
    this.parsePage(page, path + "/pages/" + x);
  }

  this.createActionLink("FormEditor.getInstance().dom2yaml();", "dom 2 yaml");

  this.root.append(this.generatedHtml);
  this.dom2yaml();
};

FormEditor.prototype.parsePage = function(page, path) {
  this.createHiddenBox(path+"/rubyobject", "Page");
  for(var y in ATTRIBUTES["Page"]) {
    var attr = ATTRIBUTES["Page"][y];
    this.createTranslateableTextBox(path + "/" + attr, attr);
  }
  var sections = page["sections"];
  for(var sect in sections) {
    var section = sections[sect];
    this.parseSection(section, path + "/sections/" + sect);
  }
};

FormEditor.prototype.parseSection = function(section, path) {
  this.createHiddenBox(path+"/rubyobject", "Section");
  for(var y in ATTRIBUTES["Section"]) {
    var attr = ATTRIBUTES["Section"][y];
    this.createTranslateableTextBox(path + "/" + attr, attr);
  }
  var questions = section["questions"];
  for(var quest in questions) {
    this.parseQuestion(questions[quest], path + "/questions/" + quest);
  }
};

FormEditor.prototype.parseQuestion = function(question, path) {
  var isMulti = this.isQuestionMulti(question);
  // present the db_column as if it were a single choice question. Add
  // _a, _b and so on later automatically
  question["is_multi"] = isMulti;
  if(isMulti) {
    var c = question["db_column"][0];
    question["db_column"] = c.substr(0, c.lastIndexOf("_"));
  }
  this.createHiddenBox(path+"/rubyobject", "Question");
  this.createSelectBox(path + "/is_multi", "is_multi", [true, false], true, "", "isMultiHasChanged");
  this.createTextBox(path + "/db_column", "db_column", true);
  var vis = ATTRIBUTES["Visualizers"][isMulti ? "Multi" : "Single"];
  this.createSelectBox(path + "/visualizer", "visualizer", vis, true);
  this.createTranslateableTextBox(path + "/qtext", "qtext");

};

FormEditor.prototype.isMultiHasChanged = function(element) {
  var path = $(element).attr("title");
  var isMulti = element.value == "true";
  var vis = ATTRIBUTES["Visualizers"][isMulti ? "Multi" : "Single"];
  var visEl = document.getElementById(path.replace(/is_multi$/, "visualizer"));
  var oldValue = visEl.value;
  $(visEl).empty();
  $(visEl).append(this.createOptionsForSelect(vis, oldValue));
};

FormEditor.prototypeParseBox = function(box, path) {

};

FormEditor.prototype.isQuestionMulti = function(question) {
  this.assert(question["db_column"] != null, "Was not given a question or it doesn’t have a db_column attribute.");
  return $.isArray(question["db_column"]);
};

FormEditor.prototype.setPath = function(obj, path, value) {
  $.each(path.split("/").reverse(), function(ind, elem) {
    if(elem == "") return;
    var v = value;
    if(elem.match(/^[0-9]+$/)) { // it’s an array
      value = [];
      value[parseInt(elem)] = v;
    } else { // it’s a hash
      value = {};
      value[elem] = v;
    }
  });
  return $.extend(true, obj, value);
};

FormEditor.prototype.translatePath = function(path, caller) {
  this.updateDataFromDom();

  // generate new object
  var oldText = this.getPath(path);
  this.log(path);
  this.log(oldText);
  var translated = { };
  $.each(this.languages, function(i, lang) {
    translated[lang] = oldText;
  });

  // inject new object
  this.setPath(this.data, path, translated);

  // update dom
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).parent().parent().html(this.generatedHtml);
};

FormEditor.prototype.groupHasDifferentInputTexts = function(parent) {
  var warn = false;
  var txt = null;
  $(parent).find("input").each(function(ind, elm) {
    if(txt != $(elm).val() && txt != null) {
      warn = true;
      return false; // break
    }
    txt = $(elm).val();
  });
  return warn;
};

FormEditor.prototype.getAttributeByIndex = function(obj, index) {
  var i = 0;
  for (var attr in obj) {
    if (index === i){
      return obj[attr];
    }
    i++;
  }
  return null;
};


FormEditor.prototype.untranslatePath = function(path, caller) {
  this.updateDataFromDom();

  var warn = this.groupHasDifferentInputTexts($(caller).parent());
  if(warn && !confirm("The translated texts differ. Keep only one?"))
    return false;

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

  // inject new object
  this.setPath(this.data, path, oldText);
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).closest(".meaningless_group").html(this.generatedHtml);
};

FormEditor.prototype.genderizePath = function(path, caller) {
  this.log("Genderizing Path: " + path);
  this.updateDataFromDom();

  // generate new object
  var oldText = this.getPath(path);
  var genderized = { ":male": oldText, ":female": oldText, ":both": oldText};

  this.log(oldText);
  this.log(genderized);

  // inject new object
  this.setPath(this.data, path, genderized);

  // update dom
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).parent().parent().parent().html(this.generatedHtml);
};

FormEditor.prototype.ungenderizePath = function(path, caller) {
  this.updateDataFromDom();
  var warn = this.groupHasDifferentInputTexts($(caller).parent());
  if(warn && !confirm("The genderized texts differ. Do you want to continue and only keep the neutral one?"))
    return false;

  var oldText = this.getPath(path + "/:both");
  // inject new object
  this.setPath(this.data, path, oldText);
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).closest(".meaningless_group").html(this.generatedHtml);
};

FormEditor.prototype.getObjectFromDom = function() {
  var obj = {rubyobject: "AbstractForm"};
  $("#form_editor input").each(function(ind, elem) {
    var path = $(elem).attr("title");
    if(!path || !path.match(/^\//))
      return true; // continue, as it’s a custom input element

    FormEditor.getInstance().setPath(obj, path, $(elem).val());
  });
  return obj;
};

FormEditor.prototype.updateDataFromDom = function() {
  this.data = this.getObjectFromDom();
};

FormEditor.prototype.dom2yaml = function() {
  $("#result").html(json2yaml(this.getObjectFromDom()));
};

FormEditor.prototype.createHeading = function(path, cssClasses) {
  var last = path.split("/").pop();
  cssClasses = cssClasses ? cssClasses : "";
  this.append('<div class="heading '+cssClasses+'"><span>'+last+'</span><div class="indent" title="'+path+'">');
};

FormEditor.prototype.closeHeading = function(path) {
  this.append("</div></div>");
};

FormEditor.prototype.createActionLink = function(action, name) {
  if(action.indexOf('"') >= 0)
    action = "eval(unescape('"+escape(action)+"'))"; // work around quotation marks
  this.append("<a onclick=\""+action+"\">"+name+"</a>");
};

FormEditor.prototype.openGroup = function(cssClasses) {
  cssClasses = cssClasses ? cssClasses : "";
  this.append('<div class="meaningless_group '+cssClasses+'">');
};

FormEditor.prototype.closeGroup = function() {
  this.append("</div>");
};

// Checks if at least one of the given translations has gendering
FormEditor.prototype.translationsHaveGendering = function(texts) {
  for(var lang in texts) {
    if(typeof(texts[lang]) != "string")
      return true;
  }
  return false;
};

FormEditor.prototype.createTranslateableTextBox = function(path) {
  var lang = [];
  var texts = this.getPath(path);

  //this.log("Creating translateable textbox at: " + path + " " + name);

  this.openGroup();
  if(typeof(texts) == "string") {
    this.openGroup();
    this.createTextBox(path, path.split("/").pop());
    this.createActionLink("FormEditor.getInstance().translatePath(\""+path+"\", this)", "Translate »");
    this.closeGroup();
  } else {
    this.createHeading(path);
    if(!this.translationsHaveGendering(texts))
      this.createActionLink("FormEditor.getInstance().untranslatePath(\""+path+"\", this)", "« Unify (no localization)");
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
  this.closeGroup();
};

FormEditor.prototype.createLangTextBox = function(path, lang) {
  var path = path+"/"+lang;
  this.openGroup("language");
  this.createTextBox(path, lang);
  this.createActionLink("FormEditor.getInstance().genderizePath(\""+path+"\", this)", "Genderize »");
  this.closeGroup();
};

FormEditor.prototype.createLangTextBoxGenderized = function(path, lang) {
  var path = path+"/"+lang;
  this.createHeading(path, "language");
  this.createActionLink("FormEditor.getInstance().ungenderizePath(\""+path+"\", this)", "« no gender");
  this.createTextBox(path + "/:both", "neutral", true);
  this.createTextBox(path + "/:female", "female", true);
  this.createTextBox(path + "/:male", "male", true);
  this.closeHeading();
};

// creates a textbox for a single value that is not translatable.
FormEditor.prototype.createTextBox = function(path, label, group, cssClasses) {
  if(path === undefined)
    throw("Given path is invalid.");
  if(label === undefined)
    throw("Given label is invalid.");

  //this.assert(typeof(this.getPath(path)) == "string", "Content for textbox is not a string. Given path: " + path);

  if(group) this.openGroup(cssClasses);

  // create unique ID for this element. It’s required for GUI uses only,
  // so we can add a random string to avoid collisions without storing
  // it for later.
  var id = path;// + "|" + Math.random(); FIXME: NEEDED?
  this.append('<label for="'+id+'">'+label+'</label>');
  this.append('<input type="text" title="'+path+'" id="'+id+'" value="'+this.getPath(path)+'"/>');

  if(group) this.closeGroup();
};

FormEditor.prototype.createHiddenBox = function(path, value) {
  this.append('<input type="hidden" title="'+path+'" value="'+value+'"/>');
};

FormEditor.prototype.createSelectBox = function(path, label, list, group, cssClasses, jsAction) {
  if(path === undefined)
    throw("Given path is invalid.");
  if(label === undefined)
    throw("Given label is invalid.");
  if(list === undefined || list.length == 0)
    throw("Given list must not be empty.");

  // random id, see createTextBox
  var id = path;// + "|" + Math.random();  FIXME: NEEDED?
  var value = this.getPath(path);

  if(group) this.openGroup(cssClasses);
  this.append('<label for="'+id+'">'+label+'</label>');
  var act = (jsAction ? 'onchange="FormEditor.prototype.'+jsAction+'(this)"' : '');
  this.append('<select id="'+id+'" title="'+path+'" '+act+'>');
  this.append(this.createOptionsForSelect(list, value));
  this.append('</select>');
  if(group) this.closeGroup();
};

FormEditor.prototype.createOptionsForSelect = function(list, selected) {
  var s = "";
  for each (item in list) {
    var sel = (item == selected ? ' selected="selected"' : '');
    s += '<option value="'+item+'"'+sel+'>'+item+'</option>';
  }
  return s;
};

// retrieves the value from the source textarea, parses it into a JS
// object and returns it.
FormEditor.prototype.getValue = function() {
  try {
    return jsyaml.load(this.source.val());
  } catch(err) {
    this.log("Error loading JS-YAML: " + err.message);
    this.invalidData = true;
  }
};

// log to Firebug and the like if available
FormEditor.prototype.log = function(strng) {
  if(window.console) console.log(strng);
};

FormEditor.prototype.trace = function() {
  if(window.console) console.trace();
}

FormEditor.prototype.assert = function(expression, message) {
  if (!expression) {
    this.invalidData = true;
    this.trace();
    throw(message);
  }
};
