/** converts all textareas to ACE Editors in place. Sets some default
 * options on the editor. Expects Prototype, ACE and mode-latex to be
 * loaded beforehand. */

if(line_offset_number == null)
  var line_offset_number = 0;

// Does some not-so-nice hot swapping so we can offset the line numbers.
// This is used to account for the lines the preamble takes up, so if
// LaTeX gives an error, the line reference will actually be correct.
function hackLineOffsetIntoAce(editor) {
  // adjust goto function
  editor.gotoLineOrig = editor.gotoLine
  editor.gotoLine = function(ln, col) {
    this.gotoLineOrig(ln-line_offset_number, col);
  }

  // adjust display of line numbers in gutter
  var upd = editor.renderer.$gutterLayer.update.toString()
    // strip of function header and its braces
    .replace(/^[^{]+{/i, "").replace(/}[^}]*$/i, "")
    // fix dom not being defined here (replace by JQuery function which
    // does the same). Looks so awkward so because some browsers insert
    // spaces and some don’t (and regexes wouldn’t be better)
    .replace("r.setInnerHtml", "this.element; $(this.element).html" )
    .replace("this.element,", "")
    // actual payload: offset line numbers
    .replace("i + 1", "i + 1 + line_offset_number")
    .replace("i+1", "i + 1 + line_offset_number");
  // convert into an actual function again and replace the original one
  editor.renderer.$gutterLayer.update  = new Function("e", upd);
}

// http://stackoverflow.com/questions/11584061/
function heightUpdateFunction(editor, containerId) {
    var newHeight = editor.getSession().getScreenLength()
                    * editor.renderer.lineHeight
                    + editor.renderer.scrollBar.getWidth();
    var con = $('#' + containerId);
    if(newHeight === con.height()) return;

    con.height(newHeight.toString() + "px");

    // This call is required for the editor to fix all of
    // its inner structure for adapting to a change in size
    editor.resize();
};


$(document).ready(function() {
  if($.browser.webkit) {
    // fix strange sizing issue with ace that only happens in Webkit
    // for some reason. See https://github.com/ajaxorg/ace/issues/1202
    $("head").append("<style>body > div { padding: 0; } </style>");
    $("body > div").css("padding", "10px");
  }


  $("textarea").each(function(index, txt) {
    txt = $(txt);
    if(txt.length == 0 || txt.attr("readonly")) return;

    // create DIV that will be used for ACE
    var id = txt.attr("id");
    $('<div id="'+id+'_ace_editor" class="ace_editor"></div>').insertAfter(txt);

    // setup ACE
    var editor = ace.edit(id + "_ace_editor");
    var session = editor.getSession();

    var texmode = require("ace/mode/" + ace_mode).Mode;
    session.setMode(new texmode());
    session.setUseWrapMode(true);
    session.setWrapLimitRange();
    editor.renderer.setHScrollBarAlwaysVisible(false);
    editor.renderer.setShowPrintMargin(false);
    if(line_offset_number != 0)
      hackLineOffsetIntoAce(editor);

    // copy textarea’s value to ACE
    session.setValue(txt.val());

    // add on submit listener to copy data back to textarea
    txt.parents("form").submit(function() {
      txt.val(session.getValue());
    });
    editor.getSession().on('change', function(){
      $formHasBeenEdited++;
      if(aceAutosize) heightUpdateFunction(editor, id+'_ace_editor');
    });

    // adjust on load
    if(aceAutosize) heightUpdateFunction(editor, id+'_ace_editor');

    // associate text field with editor, so it may easily be accessed
    txt.data("editor", editor);

    // finally hide text area
    txt.hide();
  });
});
