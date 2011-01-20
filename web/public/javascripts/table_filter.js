/* based on http://www.vonloesch.de/node/23?filt=java+
 *
 * It's kind of ugly because in its current form it only supports one
 * filter per page if the user switches faster than the timeout. While
 * that's unlikely, it should still be FIXMEd.
 * */

var timer;
var words;
var table;

function table_filter_clear(field, _id) {
  table_filter('', _id);
  if(field)
	document.getElementById(field).value='';
}

function table_filter(phrase, _id) {
  clearTimeout(timer);
  table = document.getElementById(_id);
  words = phrase.toLowerCase().split(" ");
  timer = setTimeout("table_filter_real()", 100);
}

function table_filter_real() {
  var ele;
  var odd = true;
  for (var r = 1; r < table.rows.length; r++){
	ele = table.rows[r].innerHTML.replace(/<[^>]+>/g,"").toLowerCase();
	var displayStyle = 'none';
	for (var i = 0; i < words.length; i++) {
	  if (ele.indexOf(words[i])>=0)
		displayStyle = '';
	  else {
		displayStyle = 'none';
		break;
	  }
	}
	table.rows[r].style.display = displayStyle;
	if(displayStyle == '') {
	  table.rows[r].setAttribute("class", odd ? "odd" : "even");
	  odd = !odd;
	}
  }
}
