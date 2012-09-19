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

FormEditor.prototype.allowSortingCancelByEsc = function() {
  // allow to cancel sort operations by htting esc
  $(document).keydown(function(event) {
    if(event.keyCode === $.ui.keyCode.ESCAPE) {
      FormEditor.getInstance().undoTmp = null;
      $(".sortable-question").sortable("cancel");
    }
  });
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


FormEditor.prototype.checkSectionUpDownLinks = function() {
  var allSect = $(".section h5");
  allSect.find("a").css("visibility", "visible");
  allSect.first().find("a.moveup").css("visibility", "hidden");
  allSect.last().find("a.movedown").css("visibility", "hidden");
};
