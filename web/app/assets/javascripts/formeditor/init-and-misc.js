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

  this.allowSortingCancelByEsc();
  this.toggleSorting(false);
  this.toggleDeleting(false);
  this.toggleDuplicating(false);
  this.checkSectionUpDownLinks();
  this.attachFormSubmit();
  $(document).ready(function() { $F().fixToolBoxScrolling(); });

  this.assert(this.groupTagStack.length == 0, "There are unclosed groups!");

  // hide original text edit box if form editor loaded successfully
  $("#form_content").parents("tr").hide();
}

/* Run once function that makes the #form_tools element semi-fixed.
 * Semi-fixed means it should never appear outside of its container
 * while still staying on screen when the container is. */
FormEditor.prototype.fixToolBoxScrolling = function() {
  // via http://stackoverflow.com/a/2468193, adjusted values for our
  // case. Assume only vertical scrolling is possible (lines are to be
  // seen has horizontal). Positions are absolute (relative to beginning
  // of the page).
  var box = $("#form_tools");
  var cont = box.parent();

  // position the top line of the semi-fixed box has. Needs to be
  // detected here, because it changes if the element is set to fixed.
  // Can therefore only assume it does not change -- i.e. the content
  // before it keeps its height.
  var boxTop = box.offset().top;
  // position of the top line of the container. Since we must assume
  // boxTop does not change, there’s no harm doing so here as well.
  var contTop = cont.offset().top;

  var boxHeight = box.height();
  $(window).scroll(function() {
    // top line of pixels visible
    var visTop = $(window).scrollTop();
    // position the bottom line of the container has. Assume height may
    // change.
    var contBot = contTop + cont.height();

    // if the current scroll position is less than the top position of
    // the box it means that there’s still space between the upper
    // window border and box. I.e. if it were set to fixed, it would
    // spill over the top of the container.
    var hitContTop = visTop < boxTop;
    // if the current scroll position plus the height of the box exceeds
    // the position of the container, then the box would spill over the
    // bottom of the container.
    var hitContBottom = visTop+boxHeight > contBot;

    if(hitContTop)
      box.css({ position: "relative", top: "",  right: "" });
    else if(hitContBottom)
      box.css({ position: "absolute", top: contBot-boxHeight, right: "2.1rem" });
    else
      box.css({ position: "fixed", top: "0" , right: "2.1rem"  });
  });
};

FormEditor.getInstance = function() {
  var fe = new FormEditor();
  return fe;
};

function $F() {
  return FormEditor.getInstance();
}



FormEditor.prototype.append = function(content) {
  this.generatedHtml += content + "\n";
};


FormEditor.prototype.isQuestionMulti = function(question) {
  this.assert(question["db_column"] != null, "Was not given a question or it doesn’t have a db_column attribute.");
  return $.isArray(question["db_column"]);
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
