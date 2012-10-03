/* This is file contains the init function for the form editor as well
 * as those methods that didn’t fit anywhere else.
 *
 * The form is stored as Ruby-fied YAML file, e.g. a question is not
 * simply another array entry with many attributes but marked as an
 * Ruby Question Object. That way the YAML file can be directly read
 * into an Ruby object one can work with. Since YAML is easy to read
 * for humans, it was chosen as good-enough way to edit forms before
 * the form editor was created.
 *
 * To be actually able to create the form editor visible to the user,
 * a Ruby-YAML → JS Object → DOM Elements conversion has to be made
 * and the other way round for saving. The JS Object/JSON exists in
 * the editor’s data variable but is only used as intermediate or of
 * it’s convenient to store data there and then create the DOM from it.
 *
 * YAML → JS conversion is handled by JS-YAML. Since the AbstractForm
 * and its subclasses are not part of the standard YAML specs, JS-YAML
 * has been extended a bit. You can find that at the top of json2yaml.js
 *
 * JS → YAML conversion is handled by a modified version of JSON2YAML
 * which is located at the bottom of json2yaml. The main hack is to
 * treat common "rubyobject" named elements specifically so they appear
 * as proper Ruby-YAML objects.
 *
 * JS/DOM conversions are handled in the FormEditor all over the place.
 * Also adds links/buttons and style information to actually present the
 * form to the user while processing. */

function FormEditor() {
  // singleton, via http://stackoverflow.com/a/6876814
  if(arguments.callee.instance)
    return arguments.callee.instance;
  arguments.callee.instance = this;


  this.loadFormFromTextbox();


  // listeners and other initial setup work
  $("[type=numeric]").numeric({ decimal: false, negative: false });
  this.attachSectionHeadUpdater();
  this.attachQuestionHeadUpdater();
  this.attachChangeListenerForUndo();
  this.attachCollapsers();
  this.attachTextAreaAutosize();
  this.allowSortingCancelByEsc();

  this.checkSectionUpDownLinks();
  this.attachFormSubmit();
  $(document).ready(function() { $F().fixToolBoxScrolling(); });

  this.assert(this.groupTagStack.length == 0, "There are unclosed groups!");

  // hide original text edit box if form editor loaded successfully
  $("#form_content").parents("tr").hide();
}

/* @private
 * Loads the YAML sheet from the default text area and parses it into
 * a FormEditor. Should be only called once in production mode, but may
 * be useful when debugging. */
FormEditor.prototype.loadFormFromTextbox = function() {
  // (re)set default variables
  this.undoData = new Array();
  this.redoData = new Array();
  this.undoTmp = null;
  this.groupTagStack = new Array();
  this.languages = ["en"];
  this.data = this.getValue();
  this.invalidData = false;
  this.generatedHtml = "";

  // parsing
  this.parseAbstractForm(this.data);

  this.toggleSorting(false);
  this.toggleDeleting(false);
  this.toggleDuplicating(false);
};

/* @private
 * Run once function that makes the #form_tools element semi-fixed.
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

/* @public
 * Shortcut to get the FormEditor’s instance. Creates a new one if it
 * doesn’t exist yet. */
function $F() {
  return new FormEditor();
}

/* @public
 * @param Content to append to the FormEditor’s HTML storage string */
FormEditor.prototype.append = function(content) {
  this.generatedHtml += content + "\n";
};

/* @public
 * Determines if the given JS object is a multiple choice question.
 * @param question JS object
 * @return true, iff multiple choice question */
FormEditor.prototype.isQuestionMulti = function(question) {
  this.assert(question["db_column"] != null, "Was not given a question or it doesn’t have a db_column attribute.");
  return $.isArray(question["db_column"]);
};


/* @public
 * @param String to log, if console is available */
FormEditor.prototype.log = function(strng) {
  if(window.console) console.log(strng);
};

/* @public
 * @param String to warn, if console is available */
FormEditor.prototype.warn = function(strng) {
  if(window.console) console.warn(strng);
};

/* @public
 * Inserts a stacktrace in the console, if latter is available. */
FormEditor.prototype.trace = function() {
  if(window.console) console.trace();
}

/* @public
 * Asserts given expression is true, otherwise throws message.
 * @param expression to check
 * @param message to throw, if expression is not true */
FormEditor.prototype.assert = function(expression, message) {
  if (!expression) {
    this.invalidData = true;
    this.trace();
    throw(message);
  }
};

/* @public
 * Checks if the given expression is true; prints the message if it
 * isn’t. If expression is a function, the function will be executed.
 * If there’s no error, it’s assumed everything worked fine, otherwise
 * the message will be printed. The functions return value doesn’t
 * matter.
 * @param expression to check
 * @param message to show, if expression is not true */
FormEditor.prototype.test = function(expression, message) {
  if(typeof expression === "function") {
    try {
      expression.call();
    } catch(err) {
      this.warn(message);
      this.log(err);
    }
  } else if (!expression) {
    this.warn(message);
  }
};

/* Extends jQuery’s array method to include a “unique” function. */
$.extend({
  unique : function(anArray) {
   var result = [];
   $.each(anArray, function(i,v){
      if ($.inArray(v, result) == -1) result.push(v);
   });
   return result;
  }
});
