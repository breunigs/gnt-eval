
FormEditor.prototype.updatePreviewButton = function(state) {
  if(state) {
    $("#preview").removeClass("disabled").html("Preview");
  } else {
    $("#preview").addClass("disabled").html("Previewing… <span>This might take a while</span>");
  }
};

FormEditor.prototype.preview = function() {
  if($("#preview").hasClass("disabled")) return;
  this.updatePreviewButton(false);

  if($formHasBeenEdited > 0 && !confirm("Preview requires the form to be saved first. Save form?"))
    return;

  var f = $("#form_content").parents("form");
  f.one('ajax:success ajax:error', function(event, b, status, c) {
    if(status != "success" && !event.isTrigger) {
      $F().warn("Status is " + status + ", aborting preview.");
      return;
    }

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

  if($formHasBeenEdited > 0)
    this.save();
  else
    f.trigger("ajax:success");
};
