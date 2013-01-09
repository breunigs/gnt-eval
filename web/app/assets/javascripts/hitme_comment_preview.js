var renderInProgress = false;
var renderTimeout = null;
var edit = null;

function renderPreview() {
  renderInProgress = true;
  $("#rendermsg").html("Rendering…");

  $("#previewbox").load(
    hitme_preview_url,
    { "text": edit.getValue() },
    function() {
      renderInProgress = false;
      $("#rendermsg").html('<a onclick="renderPreview()">Force Update now</a>');
    }
  );
}

$(document).ready(function() {
  edit = $("#text").data("editor").getSession();

  edit.on('change', function(){
    if(renderTimeout) clearTimeout(renderTimeout);
    if(renderInProgress) return;
    renderTimeout = setTimeout("renderPreview()", 1000);
  });

  renderPreview();
});
