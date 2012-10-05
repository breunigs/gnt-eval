/* Contains methods that either attach events to listen to user actions
 * or that are called due to an user action. */

/* @public
 * Attaches listener to all writable input elements and looks for
 * changes in them. If there are, an undo step is added. Only ever
 * needs to be called once. */
FormEditor.prototype.attachChangeListenerForUndo = function() {
  var match = "select, input, textarea";
  $("#form_editor").on("focusin change", match, function(event) {
    if(event.type == "focusin") // not a typo, focus_in_ (or focus_out_)
      $F().fillUndoTmp();
    else
      $F().addUndoStep("changing " +  event.target.id, $F().undoTmp);
  });
};

/* @public
 * Finds the contents of the first visible input-field in a section to
 * derive the title of the section from it. Only ever needs to be
 * called once. */
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

/* @public
 * Finds the contents of the first visible input-field in a question to
 * question text from it. Also finds the question’s db_column at writes
 * both to the question’s title bar. Only needs to be called once. */
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
 * Makes all text areas autosize to their content. Only needs to be
 * called once, because it listens for new text areas. */
FormEditor.prototype.attachTextAreaAutosize = function() {
  // watch for new text areas
  $('#form_editor').on("focusin", "textarea", function(ev) {
    $(this).autosize();
  });
  // areas existing initially
  $('#form_editor textarea').autosize();
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
};
