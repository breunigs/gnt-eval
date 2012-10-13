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
        if(data["viewers"] >= 2) {
          var name = getUsernameCookie();
          var s = $.map(data["users"], function(val) {
            return val === name ? val + " (this is you)" : val;
          }).join("<br>");
          $("#viewers").html(s);
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


function setUsernameCookie() {
  var name = prompt("Please set your username and possibly location, so others know who you are: (requires cookies!)", getUsernameCookie());
  if(name === null) return;
  name = escape(name.replace(/[^a-z0-9-_\s]/ig, "").substring(0, 20));
  var v = name + "; expires=Thu, 31 Dec 2020 23:59:59 GMT; path=/";
  document.cookie = "username=" + v;
};

function getUsernameCookie() {
  var all = document.cookie.split(";");
  for(i=0; i < all.length; i++) {
    name=all[i].substr(0, all[i].indexOf("="));
    value=all[i].substr(all[i].indexOf("=")+1);
    if(name === "username" && value !== "") return unescape(value);
  }
  return ident;
}
