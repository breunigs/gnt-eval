// long press button to submit associated form.
// Use via the shared/_hold_button view.
function hold_button(elem, seconds, only_once, url) {
  var t;

  var exe = function() {
    if(!confirm("Continue?")) return;

    if(only_once) {
      elem.mousedown = function () { return false; }
      elem.setAttribute("disabled", "disabled");
    }
    // set URL here to avoid non-javascript browsers from submitting
    // the button too easily
    elem.form.setAttribute("action", url);
    elem.form.submit();
  }

  elem.removeAttribute("disabled");

  elem.onclick = function (event) { event.preventDefault(); }

  elem.onmousedown = elem.ontouchstart = function() {
    if(t) clearTimeout(t);
    t = setTimeout(exe, seconds*1000);
  }

  var clear = function () { clearTimeout(t); }
  elem.onmouseup = clear;
  elem.onmouseout = clear;
  elem.ontouchend = clear;
}


// auto linkify elements with class "hold". Put the URL to
// redirect to in a data-url attribute.
$(document).ready(function() {

  $(".hold").each(function(ind, elem) {
    if(!$(elem).data("url"))
      return;

    var t;
    elem.onclick = function (event) { event.preventDefault(); }
    var exe = function() {
      window.location = $(elem).data("url");
    }
    elem.onmousedown = elem.touchstart = function() {
      if(t) clearTimeout(t);
      t = setTimeout(exe, 1000);
    }
    var clear = function () { clearTimeout(t); }
    elem.onmouseup = clear;
    elem.onmouseout = clear;
    elem.ontouchend = clear;
  });
});
