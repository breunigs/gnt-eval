
FormEditor.prototype.save = function() {
  if($("#save").hasClass("disabled")) return;
  this.updateSaveButton(false);
  setTimeout("$F().saveWorker();", 10);
};

FormEditor.prototype.saveWorker = function() {
  var f = $("#form_content").parents("form");
  this.dom2yaml();
  $formHasBeenEditedLastState = $formHasBeenEdited;

  // listen to ajax events
  f.one('ajax:success ajax:error', function(event, data, status, xhr){
    if(status == "success") {
      if($formHasBeenEditedLastState == $formHasBeenEdited)
        $formHasBeenEdited = 0; // no changes in the meantime

      $F().log("Saving was successful.");
      $F().updateSaveButton(true);
    } else {
      // error argument order: event, xhr, status, error
      alert("Saving failed. The status was: " + status + ". Maybe your backend is down? More information has been written to the console.");
      $F().log("Saving failed: --------------------------------");
      $F().log("Error:"); $F().log(xhr);
      $F().log("XHR:"); $F().log(data);
      $F().log("-----------------------------------------------");
      $F().updateSaveButton(true);
    }
  });

  // enable remote submit and request JSON version so no HTML has to be
  // generated
  f.attr("data-remote", "true");
  f.attr("action", f.attr("action") + ".json");
  f.submit();
  f.removeAttr("data-remote");
  f.attr("action", f.attr("action").slice(0,-5));
};

FormEditor.prototype.updateSaveButton = function(state) {
  if(state) {
    $("#save").removeClass("disabled").html("Save");
  } else {
    $("#save").addClass("disabled").html("Saving… <span>This might take a while</span>");
  }
};
