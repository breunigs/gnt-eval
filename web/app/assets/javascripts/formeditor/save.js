
FormEditor.prototype.save = function() {
  if($("#save").hasClass("disabled")) return;
  this.updateSaveButton(false);
  this.log("Trying to save…");
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
      $F().updateSaveButton(true);
      try {
        // rails reported errors, note the user
        if(data["status"] == 422) {
          var s = "There are some errors in your input:\n";
          var errs = JSON.parse(data["responseText"]);
          $.each(errs, function(k, v) { s += "• "+k+": "+v+"\n" });
          s += "Please fix them and try again.";
          alert(s);
          return;
        }
      } catch(e) { $F().log("Tried understanding the issue, but failed."); }


      // error argument order: event, xhr, status, error
      alert("Saving failed. The status was: " + status + ". Maybe your backend is down? More information has been written to the console.");
      $F().log("Saving failed: --------------------------------");
      $F().log("Status:"); $F().log(status);
      $F().log("Error:"); $F().log(xhr);
      $F().log("XHR:"); $F().log(data);
      $F().log("-----------------------------------------------");
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
