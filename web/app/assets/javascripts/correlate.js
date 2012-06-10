var ajax = [];

// http://snipplr.com/view/10430/
$.extend({
  keys: function(obj){
    var a = [];
    $.each(obj, function(k){ a.push(k) });
    return a;
  }
});

function getURL(correlate_by, question) {
  return root + ".json?correlate_by=" + correlate_by + "&question=" + question;
}

function strikeCorrelateByOptions() {
  var v = $("#correlate_by").val();
  $(".question option").each(function() {
    $(this).attr("disabled", v == $(this).attr("value") ? "disabled" : null);
  });
}

// executes ajax query to obtain the data and generates table and bar
// chart from it. Expects to be given the select DOM element for which
// to render the question
function getData(elem) {
  if(elem.val() == "")
    return;

  var result = elem.siblings(".result");
  if(ajax[elem.index])
    ajax[elem.index].abort();

  var url = getURL($("#correlate_by").val(), elem.val());
  ajax[elem.index] = $.ajax(url)
    .fail(function(data) { result.html("<span class=\"error\">("+data.status+") "+data.responseText+"</span>"); })
    .done(function(data) {
      var tbl = "<table><thead><tr><td></td>";
      var any_group = null;
      $.each(data, function(group, answers) {
        tbl += "<th scope=\"col\">"+group+"</th>";
        any_group = group;
      });

      tbl += "</tr></thead><tbody>";
      $.each($.keys(data[any_group]), function(ind, a) {
        tbl += "<tr><th scope=\"row\">"+a+"</th>";
        $.each(data, function(group, answers) {
          tbl += "<td>"+answers[a]+"</td>";
        });
        tbl += "</tr>";
      });
      tbl += "</tbody></table>";

      var old = result.height();

      result.html(tbl);
      result.children('table').visualize({height: 200});
      result.hide().css("height", "auto");
      var inc = result.height() - old;
      result.css("height", old+"px").show().animate({
        height: ('+=' + inc)
      });
    });
}

// creates a new question box if required (i.e. if the last one has an
// option selected). Works by copying the options from the correlation
// select box.
function createQuestionBox() {
  var q = $(".question").last();
  // don’t add a new field if there is one unused at the end
  if(q.val() == "")
    return;
  var code = "<div style=\"display:none\"><select class=\"question\"></select><div class=\"result\" style=\"height:0;overflow:hidden;\"></div></div>";
  $("#correlate_by").add(".question").last().parent().after(code);
  var q = $(".question").last();
  q.html($("#correlate_by").html().replace("selected=\"selected\"", "")); // copy options
  strikeCorrelateByOptions();
  q.change(function(){
    // handle adding/removing question blocks
    if($(this).val() == "" &&  $(".question").size() > 1) {
      $(this).parent().slideUp(600, function(){ $(this).remove(); });
      return;
    }

    if($(this).val() != "")
      createQuestionBox();
    else
      $(this).siblings(".result").html("");

    getData($(this));
  });
  q.parent().slideDown(600);
}


$(document).ready(function() {
  createQuestionBox();

  $("#correlate_by").change(function() {
    strikeCorrelateByOptions();
    $(".question").each(function(ind, elem) {
      console.log(elem);
      getData($(elem));
    });
  });

  if(question)
    $(".question option[value="+question+"]").attr("selected", "selected").change();
});
