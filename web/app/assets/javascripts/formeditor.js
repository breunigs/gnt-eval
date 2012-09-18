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

  this.undoData = new Array();
  this.redoData = new Array();
  this.undoTmp = null;
  this.groupTagStack = new Array();

  this.source = $('#form_content');
  this.root = $('#form_editor');
  this.languages = ["en"];
  this.data = this.getValue();
  this.invalidData = false;
  this.generatedHtml = "";

  this.parseAbstractForm(this.data);

  $("[type=numeric]").numeric({ decimal: false, negative: false });

  this.attachSectionHeadUpdater();
  this.attachQuestionHeadUpdater();
  this.attachChangeListenerForUndo();
  this.attachCollapsers();
  $('#form_editor textarea').autosize();

  // allow to cancel sort operations by htting esc
  $(document).keydown(function(event) {
    if(event.keyCode === $.ui.keyCode.ESCAPE) {
      FormEditor.getInstance().undoTmp = null;
      $(".sortable-question").sortable("cancel");
    }
  });

  this.toggleSorting(false);
  this.toggleDeleting(false);
  this.toggleDuplicating(false);
  this.checkSectionUpDownLinks();
  this.fixToolBoxScrolling();

  this.assert(this.groupTagStack.length == 0, "There are unclosed groups!");
}

FormEditor.prototype.save = function() {
  if($("#save").hasClass("disabled")) return;
  this.updateSaveButton(false);
  setTimeout("$F().saveWorker();", 10);
};

FormEditor.prototype.saveWorker = function() {
  var f = $("#form_content").parents("form");
  this.dom2yaml();
  $formHasBeenEditedLastState = $formHasBeenEdited;

  // listen to ajax events
  f.on('ajax:success',function(event, data, status, xhr){
    if($formHasBeenEditedLastState == $formHasBeenEdited)
      $formHasBeenEdited = 0; // no changes in the meantime

    $F().log("Saving was successful.");
    $F().updateSaveButton(true);
  });
  f.on('ajax:error',function(event, xhr, status, error) {
    alert("Saving failed. The status was: " + status + ". Maybe your backend is down? More information has been written to the console.");
    $F().log("Saving failed: --------------------------------");
    $F().log("Status:"); $F().log(status);
    $F().log("Error:"); $F().log(error);
    $F().log("XHR:"); $F().log(xhr);
    $F().log("-----------------------------------------------");
    $F().updateSaveButton(true);
  });

  // enable remote submit and request JSON version so no HTML has to be
  // generated
  f.attr("data-remote", "true");
  f.attr("action", f.attr("action") + ".json");
  f.submit();
  f.removeAttr("data-remote");
  f.attr("action", f.attr("action").slice(0,-5));
};

FormEditor.prototype.updateSaveButton = function(state) {
  if(state) {
    $("#save").removeClass("disabled").html("Save");
  } else {
    $("#save").addClass("disabled").html("Saving…");
  }
};

FormEditor.prototype.toggleSorting = function(enable) {
  enable = enable === undefined || enable === null ? $("#sort").is(":visible") : enable;
  if(enable) {
    this.makeQuestionsSortable();
    $("#sort").hide();
    $(".move, .movedown, .moveup, #cancel-sort").show();
  } else {
    $(".sortable-question").sortable("disable");
    $("#sort").show();
    $(".move, .movedown, .moveup, #cancel-sort").hide();
  }
};

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

FormEditor.prototype.toggleDuplicating = function(enable) {
  enable = enable === undefined || enable === null ? $("#duplicate").is(":visible") : enable;
  if(enable) {
    $("#duplicate").hide();
    $(".duplicate, #cancel-duplicate").show();
  } else {
    $("#duplicate").show();
    $(".duplicate, #cancel-duplicate").hide();
  }
};

FormEditor.prototype.updateActionLinksToMatchTools = function() {
  this.toggleSorting(!$("#sort").is(":visible"));
  this.toggleDeleting(!$("#delete").is(":visible"));
  this.toggleDuplicating(!$("#duplicate").is(":visible"));
};


FormEditor.prototype.fixToolBoxScrolling = function() {
  // via http://stackoverflow.com/a/2468193, adjusted values for our
  // case
  var scrollerTopMargin = $("#form_tools").offset().top;
  $(window).scroll(function() {
    var c = $(window).scrollTop();
    var d = $("#form_tools");
    if (c > scrollerTopMargin) {
      d.css({ position: "fixed", top: "0" , right: "2.1rem"  });
    } else if (c <= scrollerTopMargin) {
        d.css({ position: "relative", top: "",  right: "" });
    }
  });
};

FormEditor.prototype.makeQuestionsSortable = function() {
  $(".sortable-question").sortable({
    connectWith: ".sortable-question",
    placeholder: "sortable-question-placeholder",
    distance: 20,
    handle: "a.move",
    start: function(event, ui) {
      // undoTmp is set on mousedown in handle
      // collapse all other questions
      $(".section .collapsable:not(.closed) a.collapse").trigger("click");
    },
    beforeStop: function(event, ui) {
      var dat = FormEditor.getInstance().undoTmp;
      if(!dat) return; // probably event has been cancelled
      var t = ui.item.find("h6").data("db-column");
      FormEditor.getInstance().addUndoStep("moving question: " + t, dat);
    }
  });

  $("#form_editor").on("mousedown", "a.move", function() {
    $F().fillUndoTmp();
  });
};

FormEditor.prototype.fillUndoTmp = function() {
  this.undoTmp = $("#form_editor").html();
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

FormEditor.prototype.deleteSection = function(link) {
  var s = $(link).parents(".section");
  this.addUndoStep("deleting section " + s.children("h5").data("title"));
  s.replaceWith("");
};

FormEditor.prototype.duplicateQuestion = function(link) {
  var q = $(link).parents(".question");
  this.addUndoStep("duplicating question " + q.children("h6").data("db-column"));
  this.duplicate(q, "Question", "questions");
};

FormEditor.prototype.duplicateSection = function(link) {
  var s = $(link).parents(".section");
  this.addUndoStep("duplicating section " + s.children("h5").data("title"));
  this.duplicate(s, "Section", "sections");
};

FormEditor.prototype.duplicate = function(elm, type, pathGroup) {
  var r = new RegExp("/" + pathGroup + "/([0-9]+)/");

  // find new, not yet used id
  var lastPath = elm.parent().find("[type=hidden][value="+type+"][id^='/']").last().attr("id").match(r);
  var oldPath = "/" + pathGroup + "/" + lastPath[1] + "/";
  var newPath = "/" + pathGroup + "/" + (parseInt(lastPath[1])+1) + "/";
  var check = document.getElementById(lastPath[0].replace(oldPath, newPath));
  this.assert(check === null, "Duplicating failed as there’s already a new element with that path");

  // clone and update id/for attributes
  var newElm = elm.clone();
  newElm.find("[id^='/']").each(function(pos, elm) {
    $(elm).attr("id", $(elm).attr("id").replace(r, newPath));
  });
  newElm.find("[for^='/']").each(function(pos, elm) {
    $(elm).attr("for", $(elm).attr("for").replace(r, newPath));
  });

  newElm.insertAfter(elm);
  this.checkDuplicateIds();
};

FormEditor.prototype.moveSectionUp = function(link) {
  var allSect = $(".section");
  var sect = $(link).parents(".section");
  var pos = allSect.index(sect);
  if(pos == 0) {
    this.log("Section is already at the top");
    return;
  }
  var t = "moving section up: " + sect.find("h5").data("title");
  this.addUndoStep(t);
  if($(allSect[pos-1]).is(":last-of-type")) {
    // the previous section is the last in this page. Therefore place
    // the section to be moved after that one, so it only changes the
    // page.
    this.log("moving section only across page break");
    sect.insertAfter(allSect[pos-1]);
  } else {
    sect.insertBefore(allSect[pos-1]);
  }
  this.checkSectionUpDownLinks();
};

FormEditor.prototype.moveSectionDown = function(link) {
  var allSect = $(".section");
  var sect = $(link).parents(".section");
  var pos = allSect.index(sect);
  if(pos == allSect.length-1) {
    this.log("Section is already at the bottom");
    return;
  }
  var t = "moving section down: " + sect.find("h5").data("title");
  this.addUndoStep(t);
  if(!$(allSect[pos+1]).prev().hasClass("section")) {
    // the next section is the first of a new page. Therefore place the
    // section to be moved before that one, so it only changes the page
    this.log("moving section only across page break");
    sect.insertBefore(allSect[pos+1]);
  } else {
    sect.insertAfter(allSect[pos+1]);
  }
  this.checkSectionUpDownLinks();
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
  if(this.undoData.length > 0)
    $("#undo span").html(this.undoData.slice(-1)[0][0]);
  if(this.redoData.length > 0)
    $("#redo span").html(this.redoData.slice(-1)[0][0]);
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

FormEditor.getInstance = function() {
  var fe = new FormEditor();
  return fe;
};

FormEditor.prototype.attachChangeListenerForUndo = function() {
  var match = "#form_editor select, #form_editor input, #form_editor textarea";
  $("#form_editor").on("focusin change", match, function(event) {
    if(event.type == "focusin")
      $F().fillUndoTmp();
    else
      $F().addUndoStep("changing " +  event.target.id, $F().undoTmp);
  });
};

FormEditor.prototype.attachSectionHeadUpdater = function() {
  var s = [];
  // Selects the untranslated textboxes right after the section:
  s[0] = ".section > div.collapsable > div:first-of-type > input";
  // Selects the first translated but ungenderized textbox
  s[1] = ".section > div.collapsable .language:first-of-type > input";
  // Selects the first translated + genderized textbox
  s[2] = ".section > div.collapsable .language:first-of-type .indent > div:first-of-type > input";

  $("#form_editor").on("change", s.join(", "), function() {
    var el = $(this).parents(".section").children("h5");
    el.attr("data-title", $(this).val());
    // work around webkit not updating the element even after data-attr
    // have been changed
    if($.browser.webkit) el.replaceWith(el[0].outerHTML);
  });

  // run once for initialization
  $(s.join(", ")).trigger("change");
};

FormEditor.prototype.attachQuestionHeadUpdater = function() {
  var s = [];
  // Selects the untranslated textboxes right after the section:
  s[0] = ".question > div:first-of-type > input";
  // Selects the first translated but ungenderized textbox
  s[1] = ".question > div:first-of-type .language:first-of-type > input";
  // Selects the first translated + genderized textbox
  s[2] = ".question > div:first-of-type .language:first-of-type .indent > div:first-of-type > input";

  $("#form_editor").on("change", s.join(", "), function(){
    var el = $(this).parents(".question").children("h6");
    el.attr("data-qtext", $(this).val().slice(0,40));
    // work around webkit not updating the element even after data-attr
    // have been changed
    if($.browser.webkit) el.replaceWith(el[0].outerHTML);
  });

  $("#form_editor").on("change", ".question div.db_column input", function(){
    var el = $(this).parents(".question").children("h6");
    el.attr("data-db-column", $(this).val());
    // work around webkit not updating the element even after data-attr
    // have been changed
    if($.browser.webkit) el.replaceWith(el[0].outerHTML);
  });

  // run once for initialization
  $(s.join(", ")).trigger("change");
  $(".question div.db_column input").trigger("change");
};

FormEditor.prototype.attachCollapsers = function() {
  $("#form_editor").on("click", ".collapsable .header a.collapse", function(){
    var el = $(this).parents(".collapsable");
    if(el.hasClass("closed")) {
      // animate to old height first, then remove the fixed value so it
      // automatically adjusts to its contents. If the value isn’t
      // present, just guess and hope no one notices.
      el.animate({height: el.data("old-height") || "35rem"}, 500, function() {
        el.removeClass("closed");
        el.attr("style", "");
      });
    } else {
      el.data("old-height", el.height());
      // keep height in sync with formeditor.scss. grep this: CLOSEDHEIGHT
      el.animate({height:"3.5rem"}, 500, function() { el.addClass("closed") });
    }
  });
};

FormEditor.prototype.checkSectionUpDownLinks = function() {
  var allSect = $(".section h5");
  allSect.find("a").css("visibility", "visible");
  allSect.first().find("a.moveup").css("visibility", "hidden");
  allSect.last().find("a.movedown").css("visibility", "hidden");
};

FormEditor.prototype.setLanguagesPopup = function() {
  var dat = prompt("Enter languages this form should support. Use two-letter lang codes and separate them by spaces.", $("#availableLanguages").val());
  if(!dat || dat == $("#availableLanguages").val()) return;
  this.setLanguages(dat);
};

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

FormEditor.prototype.getDomObjFromPath = function(path) {
  return $(document.getElementById(path));
}

FormEditor.prototype.getPathDepth = function(path) {
  return path.split("/").length - 1;
};

FormEditor.prototype.createAvailLangBox = function() {
  var langString = this.languages.join(" ").replace(/:/g, "");
  this.createHiddenBox("availableLanguages", langString);
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

  this.createAvailLangBox();

  this.createTextBox(path + "/db_table", "database table");
  this.append("<br/>");

  for(var x in data) {
    var d = this.data[x];
    if(x.match("rubyobject|pages|db_table$"))
      continue;

    this.assert($.inArray(ATTRIBUTES["AbstractForm"].x), "The given data subset contains an unknown attribute for AbstractForm: " + x + ".");

    this.createTranslateableTextBox(path + "/" + x, x);
  }

  for(var x in this.data["pages"]) {
    var page = this.data["pages"][x];
    this.parsePage(page, path + "/pages/" + x);
  }

  this.root.append(this.generatedHtml);
  this.dom2yaml();
};

FormEditor.prototype.parsePage = function(page, path) {
  this.openGroup("page");
  this.createHiddenBox(path+"/rubyobject", "Page");
  this.append('<a class="delete" onclick="$F().deletePageBreak(this)" title="Delete Page Break" style="display: none;">⌫</a>');
  for(var y in ATTRIBUTES["Page"]) {
    var attr = ATTRIBUTES["Page"][y];
    this.createTranslateableTextBox(path + "/" + attr, attr);
  }
  var sections = page["sections"];
  for(var sect in sections) {
    var section = sections[sect];
    this.parseSection(section, path + "/sections/" + sect);
  }
  this.closeGroup();
};

FormEditor.prototype.parseSection = function(section, path) {
  this.openGroup("section");
  this.append('<h5 class="header">');
  this.append('<a class="moveup" onclick="$F().moveSectionUp(this);" title="move section one block up">↑</a>');
  this.append('<a class="movedown" onclick="$F().moveSectionDown(this);" title="move section one block down">↓</a>');
  this.append('<a class="duplicate" title="Duplicate Section" onclick="$F().duplicateSection(this)">⎘</a>');
  this.append('<a class="delete" title="Delete Section" onclick="$F().deleteSection(this)">×</a>');
  this.append('</h5>');


  this.openGroup("collapsable closed");
  this.append('<h6 class="header">header details<a title="Collapse/Expand" class="collapse"></a></h6>');
  this.createHiddenBox(path+"/rubyobject", "Section");
  for(var y in ATTRIBUTES["Section"]) {
    var attr = ATTRIBUTES["Section"][y];
    this.createTranslateableTextBox(path + "/" + attr, attr);
  }
  section["answers"] = section["answers"] || [];
  this.createTranslateableTextArea(path + "/answers");
  this.closeGroup();

  var questions = section["questions"];
  this.openGroup("sortable-question", "ol");
  for(var quest in questions) {
    this.parseQuestion(questions[quest], path + "/questions/" + quest);
  }
  this.closeGroup();
  this.closeGroup();
};

FormEditor.prototype.parseQuestion = function(question, path) {
  this.openGroup("question collapsable closed", "li");
  this.append('<h6 class="header">');
  this.append('<a class="collapse" title="Collapse/Expand"></a>');
  this.append('<a class="move" title="Move/Sort (use drag and drop; hit escape to cancel)">⬍</a>');
  this.append('<a class="duplicate" title="Duplicate Question" onclick="$F().duplicateQuestion(this)">⎘</a>');
  this.append('<a class="delete" title="Delete Question" onclick="$F().deleteQuestion(this)">×</a>');
  this.append('</h6>');
  this.createHiddenBox(path+"/rubyobject", "Question");
  this.createTranslateableTextBox(path + "/qtext", "qtext");
  var isMulti = this.isQuestionMulti(question);
  // TODO: fix how type works elsewhere and merge with multi-choice
  var typeTranslation = {"square": "Single", "tutor_table": "Tutor", "text": "Text" };
  question["type"] = isMulti ? "Multi" : typeTranslation[question["type"]];
  question["repeat_for"] = question["repeat_for"] || "only_once";
  if(isMulti) {
    var c = question["db_column"][0];
    question["db_column"] = c.substr(0, c.lastIndexOf("_"));
  }

  this.createSelectBox(path + "/type", "type", Object.keys(ATTRIBUTES["Visualizers"]), true, "", "questionTypeChanged");
  this.createTextBox(path + "/db_column", "db_column", true, "db_column");

  // these boxes depend on the question type. They are created in HTML
  // but may be hidden. Their values are discarded when generating the
  // final YAML, but they are present in the JS-data structure.
  this.createHideAnswersBox(question, path);
  this.createLastIsTextBox(question, path);
  this.createHeightBox(question, path);

  var vis = ATTRIBUTES["Visualizers"][question["type"]];
  this.createSelectBox(path + "/visualizer", "visualizer", vis, true);
  this.createSelectBox(path + "/repeat_for", "repeat_for", ["only_once", "lecturer", "tutor"], true);

  this.parseBoxes(question, path);
  this.closeGroup();
};

FormEditor.prototype.questionTypeChanged = function(element) {
  var path = $(element).attr("id").replace(/\/type$/, "");
  var vis = ATTRIBUTES["Visualizers"][element.value];
  this.assert(vis, "Unsupported question type: " + element.value);
  var visEl = document.getElementById(path + "/visualizer");
  var oldValue = visEl.value;
  $(visEl).empty();
  $(visEl).append(this.createOptionsForSelect(vis, oldValue));

  if(element.value == "Single") {
    this.getDomObjFromPath(path + "/hide_answers").parent().show();
    this.getDomObjFromPath(path + "/last_is_textbox").parent().show();
  } else {
    this.getDomObjFromPath(path + "/hide_answers").parent().hide();
    this.getDomObjFromPath(path + "/last_is_textbox").parent().hide();
  }

  if(element.value == "Text")
    this.getDomObjFromPath(path + "/height").parent().show();
  else
    this.getDomObjFromPath(path + "/height").parent().hide();

  if(element.value == "Tutor" || element.value == "Text")
    this.getDomObjFromPath(path + "/boxes/0/rubyobject").parent().hide();
  else
    this.getDomObjFromPath(path + "/boxes/0/rubyobject").parent().show();
};

FormEditor.prototype.parseBoxes = function(question, path) {
  this.openGroup("boxes");
  for(var ind in question["boxes"]) {
    var bpath = path + "/boxes/" + ind;
    var box = question["boxes"][ind];
    box["text"] = box["text"] || "";
    this.createHiddenBox(bpath + "/rubyobject", "Box");
    this.createTranslateableTextBox(bpath + "/text");
  }
  this.closeGroup();
};

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

FormEditor.prototype.getObjectFromDom = function() {
  var obj = {rubyobject: "AbstractForm"};
  $("#form_editor input, #form_editor select, #form_editor textarea").each(function(ind, elem) {
    var path = $(elem).attr("id");
    var type = $(elem).attr("type");
    // continue, as it’s a custom input element or it is hidden
    if(!path || !path.match(/^\//) || (!$(elem).is(":visible") && type != "hidden"))
      return true;

    var v = $(elem).val();
    // convert values to their proper types
    if(type == "checkbox") v = $(elem).is(":checked");
    if(type == "numeric") v = parseFloat(v);
    if($(elem).prop("tagName") == "TEXTAREA") {
      if(v == "") return true;
      v = v.split("\n");
      for(var ind in v) {
        if(v[ind] == "")
          v[ind] = null;
      }
    }

    // skip these default values
    if(path.match(/\/last_is_textbox$/) && v == "0") return true;
    if(path.match(/\/boxes\/[0-9]+\/text$/) && v == "") return true;
    if(path.match(/\/hide_answers$/) && !v) return true;
    if(path.match(/\/repeat_for$/) && v == "only_once") return true;

    FormEditor.getInstance().setPath(obj, path, v);
  });

  // post-processing required for correct type and db_column fields.
  // should be removed once the type-field has been updated (TODO). Also
  // removed "undefined" array entries which may appear due to original
  // part being deleted.
  obj["pages"] = obj["pages"].filter(function(){return true});
  $.each(obj["pages"], function(ind, page) {
    page["sections"] = page["sections"].filter(function(){return true});
    $.each(page["sections"], function(ind, sect) {
      sect["questions"] = sect["questions"].filter(function(){return true});
      $.each(sect["questions"], function(ind, quest) {
        switch(quest["type"]) {
          case "Single":
            quest["type"] = "square";
            break;
          case "Multi":
            quest["type"] = "square";
            var a = [];
            for(var i = 0; i < quest["boxes"].length; i++) {
              a[i] = quest["db_column"] + "_" + String.fromCharCode(97+i);
            }
            quest["db_column"] = a;
            break;
          case "Text":
            quest["type"] = "text";
            quest["boxes"] = [];
            break;
          case "Tutor":
            quest["type"] = "tutor_table";
            quest["boxes"] = null;
            break;
          default:
            throw("Unsupported question type: " + quest["type"]);
        }
      });
    });
  });
  return obj;
};

FormEditor.prototype.checkDuplicateIds = function() {
  var ids = [];
  $('[id]').each(function(){
    $F().assert(ids.indexOf(this.id) < 0, 'Multiple IDs #'+this.id);
    ids.push(this.id);
  });
};

FormEditor.prototype.updateDataFromDom = function() {
  this.data = this.getObjectFromDom();
};

FormEditor.prototype.dom2yaml = function() {
  $("#form_content").html(json2yaml(this.getObjectFromDom()));
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
};

// does not support genderization. Creates a textarea instead to allow
// easy creation of an array.
FormEditor.prototype.createTranslateableTextArea = function(path) {
  var lang = [];
  var texts = this.getPath(path);

  this.openGroup();
  if($.isArray(texts)) {
    this.openGroup();
    this.createTextArea(path, path.split("/").pop());
    this.createActionLink("FormEditor.getInstance().translatePath(\""+path+"\", this)", "Translate »");
    this.closeGroup();
  } else {
    this.createHeading(path);
    this.createActionLink("FormEditor.getInstance().untranslatePath(\""+path+"\", this)", "« Unify (no localization)");
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
  this.createActionLink("FormEditor.getInstance().genderizePath(\""+path+"\", this)", "Genderize »", "genderize");
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
  this.createActionLink("FormEditor.getInstance().ungenderizePath(\""+path+"\", this)", "« no gender");
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

FormEditor.prototype.warn = function(strng) {
  if(window.console) console.warn(strng);
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

function $F() {
  return FormEditor.getInstance();
}
