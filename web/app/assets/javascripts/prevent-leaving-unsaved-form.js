var $formHasBeenEdited = false;
var $formIsBeingSubmitted = false;

$(document).ready(function() {
  var m = "form[method='post'] input, form[method='post'] select, form[method='post'] textarea";
  $(m).one("change", function() {
    $formHasBeenEdited = true;
  });

  $("form[method='post']").submit(function() {
    $formIsBeingSubmitted = true;
    return true;
  });
});

$(window).bind('beforeunload', function() {
  if($formIsBeingSubmitted) {
    $formIsBeingSubmitted = false;
    return null;
  }

  if($formHasBeenEdited)
    return 'Are you sure you want to leave?';
  else
    return null;
});
