/* offers functions that allow the sorting of questions and sections.
 * Page breaks may not be sorted, instead the sections should be moved
 * around. Boxes also cannot be switched, their text needs to be copied
 * and pasted.
 *
 * Questions may be dragged and dropped. Sections have up/down buttons
 * to move the one up/down. */

/* @public
 * Shows/hides the sorting buttons on sections/questions.
 * @param enable  if the buttons should be shown/hidden. */
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

/* @public
 * Attaches a key listener to allow cancelling a drag and drop move with
 * ESC. Only needs to be executed once */
FormEditor.prototype.allowSortingCancelByEsc = function() {
  // allow to cancel sort operations by htting esc
  $(document).keydown(function(event) {
    if(event.keyCode === $.ui.keyCode.ESCAPE) {
      $F().undoTmp = null;
      $(".sortable-question").sortable("cancel");
    }
  });
};

/* @public
 * Moves section one position up.
 * @param DOM reference of an element within the section group so that
 *        the section may be defined. */
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

/* @public
 * Moves section one position down.
 * @param DOM reference of an element within the section group so that
 *        the section may be defined. */
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

/* @public
 * shows section up/down links, but hides the corresponding link if it’s
 * the top or bottommost section */
FormEditor.prototype.checkSectionUpDownLinks = function() {
  var allSect = $(".section h5");
  allSect.find("a").css("visibility", "visible");
  allSect.first().find("a.moveup").css("visibility", "hidden");
  allSect.last().find("a.movedown").css("visibility", "hidden");
};

/* @private
 * Puts questions into jQuery-UI sortable and attaches listeners to
 * handle undo and the like. */
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
    update: function(event, ui) {
      var dat = $F().undoTmp;
      if(!dat) return; // probably event has been cancelled
      var t = ui.item.find("h6").data("db-column");
      $F().addUndoStep("moving question: " + t, dat);
      $F().renumberElements();
    }
  });

  $("#form_editor").on("mousedown", "a.move", function() {
    $F().fillUndoTmp();
  });
};

/* @private
 * Renumbers all elements according to their position in the DOM. After
 * calling this DOM position and path/id will match up. */
FormEditor.prototype.renumberElements = function() {
  this.log("Renumbering elements…");
  var page = -1,
    section = -1,
    question = -1;
  $("#form_editor [id^='/'], #form_editor label[for^='/']").each(function(ind, elem) {
    var elem = $(elem);
    var path = elem.attr("id") || elem.attr("for");

    if(elem.attr("type") === "hidden" && path.indexOf("/rubyobject", path.length-11) !== -1) {
      switch(elem.val()) {
        case "Page":     page++;    section=-1; question=-1; break;
        case "Section":             section++;  question=-1; break;
        case "Question":                        question++; break;
      }
    }

    path = path.replace(/^\/pages\/[0-9]+\//, "/pages/"+page+"/");
    path = path.replace(/^(\/pages\/[0-9]+\/sections\/)[0-9]+\//, "$1"+section+"/");
    path = path.replace(/^(\/pages\/[0-9]+\/sections\/[0-9]+\/questions\/)[0-9]+\//, "$1"+question+"/");

    elem.attr(elem.prop("tagName") === "LABEL" ? "for" : "id", path);
  });
  this.checkDuplicateIds();
};
