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

  this.allowSortingCancelByEsc();
  this.toggleSorting(false);
  this.toggleDeleting(false);
  this.toggleDuplicating(false);
  this.checkSectionUpDownLinks();
  this.fixToolBoxScrolling();

  this.assert(this.groupTagStack.length == 0, "There are unclosed groups!");
}


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
