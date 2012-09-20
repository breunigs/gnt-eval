/* this file contains all necessary functions to allow the form to be
 * saved without actually changing the page. It’s intended to not be
 * blocked, even if the form has errors because creating a form is a lot
 * of effort and we do not want to prevent saving unfinished work.
 *
 * The basic idea is to make the "remote" and let Rails code deal with
 * the details. Also append .josn to the action URL so that we get data
 * tailored to our case. If a form is edited, no values are required.
 * New forms need to be changed to an "edit form" so that updating them
 * again works properly (and some other stuff).
 *
 * We attach ajax listeners to the form in order to handle success or
 * errors of the submit */

/* @public
 * Inits the ajax save action for the current forms. Returns nothing
 * and does not block until the form is saved. */
FormEditor.prototype.save = function() {
  if($("#save").hasClass("disabled")) return;
  this.updateSaveButton(false);
  this.log("Trying to save…");
  setTimeout("$F().saveWorker();", 10);
};

/* @private
 * Does the heavy lifing when saving, i.e. actually submitting and
 * listening to ajax events. Alerts the user of errors if possible
 * or prints information to console if not. */
FormEditor.prototype.saveWorker = function() {
  var f = $("#form_content").parents("form");
  this.dom2yaml();
  $formHasBeenEditedLastState = $formHasBeenEdited;

  // listen to ajax events
  f.one('ajax:success ajax:error', function(event, data, status, xhr) {
    if(status == "success") {
      if($formHasBeenEditedLastState == $formHasBeenEdited)
        $formHasBeenEdited = 0; // no changes in the meantime

      // replace new form with edit-style one
      if($("#new_form").length) {
        $("head").append($(data["collision"]));
        $("#new_form").replaceWith($(data["form"]));
        ATTRIBUTES["PreviewUrl"] = data["preview"];
        // hide original textbox again
        $("#form_content").parents("tr").hide();
      }

      $F().log("Saving was successful.");
      $F().updateSaveButton(true);
    } else {
      $F().updateSaveButton(true);
      var handeled = false;
      try {
        // rails reported errors, note the user
        if(data["status"] == 422) {
          var s = "There are some errors in your input:\n";
          var errs = JSON.parse(data["responseText"]);
          $.each(errs, function(k, v) { s += "• "+k+": "+v+"\n" });
          s += "Please fix them and try again.";
          alert(s);
          handeled = true;
        }
      } catch(e) { $F().log("Tried understanding the issue, but failed."); }

      if(!handeled) {
        // error argument order: event, xhr, status, error
        alert("Saving failed. The status was: " + status + ". Maybe your backend is down? More information has been written to the console.");
        $F().log("Saving failed: --------------------------------");
        $F().log("Status:"); $F().log(status);
        $F().log("Error:"); $F().log(xhr);
        $F().log("XHR:"); $F().log(data);
        $F().log("-----------------------------------------------");
      }

      // re-enable preview in case it issued the save command
      $F().updatePreviewButton(true);
    }
  });

  // enable remote submit and request JSON version so no HTML has to be
  // generated
  f.data("remote", "true");
  f.attr("action", f.attr("action") + ".json");
  f.submit();
  // NB: attr("data-remote") != data("remote"). If the actual HTML5
  // data-remote attribute was set, we would need f.removeAttr before
  // f.removeData in order to really remove the value. See:
  // See http://stackoverflow.com/a/12504660/1684530
  f.removeData("remote");
  f.attr("action", f.attr("action").slice(0,-5));
};

/* @private
 * Helper function that en- or disables the save button depending on the
 * given argument. Returns nothing */
FormEditor.prototype.updateSaveButton = function(state) {
  if(state) {
    $("#save").removeClass("disabled").html("Save");
  } else {
    $("#save").addClass("disabled").html("Saving… <span>This might take a while</span>");
  }
};
