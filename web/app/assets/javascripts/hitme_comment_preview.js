var renderTimeout = {};
var renderInProgress = {};
if(typeof listify === 'undefined') var listify = false;

function renderPreview(id) {
  renderInProgress[id] = true;

  var edit = $("#"+id).data("editor");

  var con = $("#"+id).parent().find(".previewbox");
  con.children(".rendermsg").html("Rendering…");

  var d = con.children("div");
  d.css('height', d.height());
  d.load(
    hitme_preview_url,
    { "text": edit.getValue(), "listify": listify },
    function() {
      // http://stackoverflow.com/a/4086085/1684530
      $(this).wrapInner('<div/>');
      $(this).animate({height: $('div:first', this).height()} );
      con.children(".rendermsg").html('<a onclick="renderPreview(\''+id+'\')">Force Update now</a>');
      renderInProgress[id] = false;
    }
  );
}


$(document).ready(function() {
  $(".containersplit #text, textarea.previewable").each(function(ind, txt) {
    var txt = $(txt);
    var id = txt.attr("id");

    txt.data("editor").getSession().on('change', function(){
      var rt = renderTimeout[id];
      if(rt) clearTimeout(rt);
      if(renderInProgress[id]) return;
      renderTimeout[id] = setTimeout("renderPreview('"+id+"')", 1000);
    });

    renderTimeout[id] = setTimeout("renderPreview('"+id+"')", 400);
  });

});
