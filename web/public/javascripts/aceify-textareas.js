/** converts all textareas to ACE Editors in place. Sets some default
 * options on the editor. Expects Prototype, ACE and mode-latex to be
 * loaded beforehand. */

if(line_offset_number == null)
  var line_offset_number = 0;

// Does some not-so-nice hot swapping so we can offset the line numbers.
// This is used to account for the lines the preamble takes up, so if
// LaTeX gives an error, the line reference will actually be correct.
function hack_line_offset_into_ace(editor) {
  // adjust goto function
  editor.gotoLineOrig = editor.gotoLine
  editor.gotoLine = function(ln, col) {
    this.gotoLineOrig(ln-line_offset_number, col);
  }

  // compression changes: a == config; d == dom, c == html; e == i
  // adjust display of line numbers in gutter
  var upd = editor.renderer.$gutterLayer.update.toString()
    // strip of function header and its braces
    .replace(/^[^{]+{/i, "").replace(/}[^}]*$/i, "")
    // fix dom not being defined here (replace by Prototype
    // function which does the same)
    .replace("this.element = d.setInnerHtml(this.element, c.join(\"\"))",
             "this.element.update(c.join(\"\"))" )
    // actual payload: offset line numbers
    .replace("a.lineHeight, \"px;'>\", e + 1);",
             "a.lineHeight, \"px;'>\", e + 1 + line_offset_number);");
  // convert into an actual function again and replace the original one
  editor.renderer.$gutterLayer.update  = new Function("a", upd);
}

window.onload = function() {
  $$("textarea").each(function(txt) {
    if(txt.hasAttribute("readonly"))
      return;
    // create DIV that will be used for ACE
    var id = txt.readAttribute("id");
    var d = document.createElement('div');
    d.writeAttribute("id", id + "_ace_editor");
    d.addClassName("ace_editor");
    txt.insert({'after': d});

    // setup ACE
    var editor = ace.edit(id + "_ace_editor");
    
    var texmode = require("ace/mode/" + ace_mode).Mode;
    editor.getSession().setMode(new texmode());
    editor.getSession().setUseWrapMode(true);
    editor.getSession().setWrapLimitRange();
    editor.renderer.setHScrollBarAlwaysVisible(false);
    editor.renderer.setShowPrintMargin(false);
    hack_line_offset_into_ace(editor);

    // copy textarea’s value to ACE
    editor.getSession().setValue($F(id));

    // add on submit listener to copy data back to textarea
    Event.observe(txt.up("form"), 'submit', function(event) {
      txt.value = editor.getSession().getValue();
    });

    // finally hide text area
    txt.hide();
  });
};
