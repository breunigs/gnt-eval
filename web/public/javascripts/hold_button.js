function hold_button(elem, seconds, only_once) {
  var t;

  var exe = function() {
    if(only_once) {
      elem.mousedown = function () { return false; }
      elem.setAttribute("disabled", "disabled");
    }
    elem.form.submit();
  }

  elem.removeAttribute("disabled");

  elem.onclick = function (event) { event.preventDefault(); }

  elem.onmousedown = function() {
    if(t) clearTimeout(t);
    t = setTimeout(exe, seconds*1000);
  }

  var clear = function () { clearTimeout(t); }
  elem.onmouseup = clear;
  elem.onmouseout = clear;
}
