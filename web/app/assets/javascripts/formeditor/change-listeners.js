
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


FormEditor.prototype.attachFormSubmit = function() {
  $("body").on("submit", "form", function(ev) {
    if($(this).find("#form_content").length == 0)
      return;

    $F().dom2yaml();
  });
};
