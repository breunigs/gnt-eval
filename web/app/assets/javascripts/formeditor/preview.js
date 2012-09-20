/* Allow previewing the current form. First saves the current state and
 * then ajax-requests the normal preview partial. */

/* @public
 * attaches listener to the ajax success form event and either saves the
 * form or simulates it. If saving fails, the save function re-enables
 * the preview button. If saving worked, the normal preview page is
 * being requested and injected into DOM once rendered. */
FormEditor.prototype.preview = function() {
  if($("#preview").hasClass("disabled")) return;

  var needsSave = ATTRIBUTES["PreviewUrl"] == null || $formHasBeenEdited > 0;
  if(needsSave && !confirm("Preview requires the form to be saved first. Save form?"))
    return;

  this.updatePreviewButton(false);

  var f = $("#form_content").parents("form");
  // fail is handled directly in save
  f.one('ajax:success', function(event, b, status, c) {
    $("#form_preview").one("click", function() {
      $F().updatePreviewButton(true);
      $("#form_preview").fadeOut("fast", function() {
        $("#form_preview").html("");
      });
      $("#darkened2").fadeOut();
    });

    $("#form_preview").load(ATTRIBUTES["PreviewUrl"], function() {
      $("#form_preview").fadeIn();
      $("#darkened2").fadeIn();
    });
  });

  if(needsSave)
    this.save();
  else
    f.trigger("ajax:success");
};

/* @private
 * Helper function that en- or disables the preview button depending on
 * the given argument. Returns nothing */
FormEditor.prototype.updatePreviewButton = function(state) {
  if(state) {
    $("#preview").removeClass("disabled").html("Preview");
  } else {
    $("#preview").addClass("disabled").html("Previewing… <span>This might take a while</span>");
  }
};
