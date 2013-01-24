var $formHasBeenEdited = 0;
var $formIsBeingSubmitted = false;

$(document).ready(function() {
  var m = "form[method='post'] input, form[method='post'] select, form[method='post'] textarea";
  $(m).change(function() {
    $formHasBeenEdited++;
  });

  $("form[method='post']").submit(function() {
    $formIsBeingSubmitted = true;
    return true;
  });
});

$(window).bind('beforeunload', function() {
  if($formIsBeingSubmitted) {
    // timeout required because beforeunload may be fired multiple times
    setTimeout("$formIsBeingSubmitted = false", 500);
    return null;
  }

  if($formHasBeenEdited > 0)
    return 'Are you sure you want to leave?';
  else
    return null;
});
