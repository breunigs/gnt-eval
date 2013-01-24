// auto linkify elements with class "hold". Put the URL to
// redirect to in a data-url attribute.
// Other options:
// data-time -- seconds the button needs to be held
// data-post -- fill with authenticity_token to submit via POST instead
// data-onlyonce -- disable button after submission
// data-group -- if onlyonce is specified, all buttons in this group
//               will be disabled
// See web/app/views/shared/_hold_button.html.erb for an example
$(document).ready(function() {

  $(".hold").each(function(ind, elem) {
    var e = $(elem);
    if(!e.data("url") || e.hasClass("disabled"))
      return;

    var t;
    elem.onclick = function (event) { event.preventDefault(); }
    var exe = function() {
      if(e.data("onlyonce")) {
        $("[data-group='"+e.data("group")+"']").addClass("disabled");
        e.addClass("disabled");
      }

      if(e.data("post")) {
        $('body').append($('<form/>')
        .attr({'action': e.data("url"), 'method': 'post', "id": "post_location"})
        .append($('<input/>').attr({'type': 'hidden', 'name': 'authenticity_token', 'value': e.data("post")})
        )).find("#post_location").submit();
      } else {
        window.location = e.data("url");
      }
    }
    elem.onmousedown = elem.touchstart = function() {
      if(t) clearTimeout(t);
      t = setTimeout(exe, 1000*(e.data("time") || 1 ));
    }
    var clear = function () { clearTimeout(t); }
    elem.onmouseup = clear;
    elem.onmouseout = clear;
    elem.ontouchend = clear;
  });
});
