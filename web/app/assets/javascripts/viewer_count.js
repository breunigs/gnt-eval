var ident = Math.random().toString(36).substring(2,11);
// these have been defined in the viewer so the links may be generated
// using Rails
ping = ping.replace("PLACEHOLDER", ident);
unping = unping.replace("PLACEHOLDER", ident);

$(document).ready(function() {
  // periodically asks for the current viewers, but prevents overlapping
  // events by waiting for the prior one to complete.
  // via http://stackoverflow.com/a/5052661
  (function worker() {
    $.ajax({
      url: ping,
      success: function(data) {
        // hide and show collision warning, but respect collapsed state
        var w = $("#collision-warning");
        var d = $("#darkened");
        if(data >= 2) {
          w.removeClass("hidden");
          if(!w.hasClass("collapsed")) d.fadeIn();
        } else {
          // reset state, so that the user will be notified again if a
          // new collision problem might occur
          w.removeClass("collapsed");
          w.addClass("hidden");
          d.fadeOut();
        }
      },
      complete: function() {
        setTimeout(worker, 10000);
      }
    });
  })();

  // remove oneself from the sessions on window close
  $(window).unload( function () {
    $.ajax({url: unping, async:false})
  });

  // warning toggling
  $("#collision-warning").click(function() {
    var activate = $(this).hasClass("collapsed");
    $(this).toggleClass("collapsed", !activate)
    if(activate)
      $("#darkened").fadeIn();
    else
      $("#darkened").fadeOut();
  });
});