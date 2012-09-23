$(document).ready(function() {
    var t = $("#tablemagic");
    var f = $("#filterfield");
    t.tablesorter({widthFixed: true, widgets: ['zebra']});
    f.bind("keyup change", function() {
      $.uiTableFilter(t, this.value);
      // fix zebra striping.
      $("#tablemagic tr:visible:even").removeClass("odd").addClass("even");
      $("#tablemagic tr:visible:odd").removeClass("even").addClass("odd");
    }).trigger("change");
});
