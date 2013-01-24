/* Contains methods that either attach events to listen to user actions
 * or that are called due to an user action. */

/* @public
 * Attaches listener to all writable input elements and looks for
 * changes in them. If there are, an undo step is added. It also updates
 * the section/question headers, if the changed field is used in the
 * header. Only ever needs to be called once. */
FormEditor.prototype.attachChangeListenerToAllInputs = function() {
  var match = "select, input, textarea";
  $("#form_editor").on("focusin change", match, function(event) {
    if(event.type == "focusin") // not a typo, focus_in_ (or focus_out_)
      $F().fillUndoTmp();
    else {
      $F().addUndoStep("changing " + event.target.id, $F().undoTmp);
      $F().handleSectionAndQuestionUpdates($(event.target));
    }
  });
};

/* @public
 * Sets up the question and section headers with detailed info. Only
 * should be called once; after the form has loaded. */
FormEditor.prototype.initSectionAndQuestionHeaders = function() {
  // likely candidates that will be required for the header.
  var s = "input[id*='/title'], input[id*='/qtext'], .db_column input";
  $(s).each(function(ind, elm) {
    $F().handleSectionAndQuestionUpdates($(elm));
  });
};

/* @public
 * Checks if the given element is used to generate the header info. If
 * it is, the header will be updated automatically. */
FormEditor.prototype.handleSectionAndQuestionUpdates = function(elm) {
  if(!elm.is("input")) return;
  var id = elm.attr("id");

  if(id.indexOf("/title") !== -1) {
    var section = elm.parents(".section");
    var title = section.find("input[id*='/title']:first");
    if(id === title.attr("id")) {
      var el = section.children("h5");
      el.attr("data-title", elm.val());
      // work around webkit not updating the element even after data-attr
      // have been changed
      if($.browser.webkit) el.replaceWith(el[0].outerHTML);
      return;
    }
  }

  if(id.indexOf("/qtext") !== -1) {
    var q = elm.parents(".question");
    var qtext = q.find("input[id*='/qtext']:first");
    if(id === qtext.attr("id")) {
      var el = q.children("h6");
      el.attr("data-qtext", elm.val());
      if($.browser.webkit) el.replaceWith(el[0].outerHTML);
      return;
    }
  }

  if(id.indexOf("/db_column") !== -1) {
    var q = elm.parents(".question");
    var dbcol = q.find(".db_column input");
    if(id === dbcol.attr("id")) {
      var el = q.children("h6");
      el.attr("data-db-column", elm.val());
      if($.browser.webkit) el.replaceWith(el[0].outerHTML);
    }
  }
};

/* @public
 * Attaches events to collapse/show links that actually allow collapsing
 * or showing that DOM element. Since the elements are hidden initially
 * their height is unknown and a proper slideDown animation is not
 * possible. In that case, just guess the height. Only needs to be
 * called once. */
FormEditor.prototype.attachCollapsers = function() {
  $("#form_editor").on("click", ".collapsable .header a.collapse", function(){
    var el = $(this).parents(".collapsable");
    if(el.hasClass("closed")) {
      el.find("textarea").autosize();
      // animate to old height first, then remove the fixed value so it
      // automatically adjusts to its contents. If the value isn’t
      // present, just guess and hope no one notices.
      el.animate({height: el.data("old-height") || "35rem"}, $F().animationSpeed, function() {
        el.removeClass("closed");
        el.attr("style", "");
        $(window).scroll(); // re-position toolbox
      });
    } else {
      el.data("old-height", el.height());
      // keep height in sync with formeditor.scss. grep this: CLOSEDHEIGHT
      el.animate({height:"3.5rem"}, $F().animationSpeed, function() {
        $(window).scroll(); // re-position toolbox
        el.addClass("closed")
      });
    }
  });
};


/* @public
 * Attaches listener to the original form tag. On submission parses the
 * form into YAML in the original textarea. */
FormEditor.prototype.attachFormSubmit = function() {
  $("body").on("submit", "form", function(ev) {
    if($(this).find("#form_content").length == 0)
      return;

    $F().dom2yaml();
  });
};

/* @public
 * Called when the user changes type of a question. Handles showing
 * and hiding the appropriate boxes, checkmarks, etc. for that question
 * type. */
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
    this.getDomObjFromPath(path + "/boxes").parent().hide();
  else
    this.getDomObjFromPath(path + "/boxes").parent().show();

  // hide the lecturer option for text fields because it is not implemented
  // Since by default single question is chosen, it should not be possible
  // for this option to appear unless it’s wrong to begin with.
  var rf = $F().getDomObjFromPath(path + "/repeat_for");
  rf.children("[value=lecturer]").toggle(element.value != "Text");
  if(element.value === "Text" && rf.val() === "lecturer")
    rf.val("only_once");
};
