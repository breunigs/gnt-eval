
// retrieves the value from the source textarea, parses it into a JS
// object and returns it.
FormEditor.prototype.getValue = function() {
  try {
    return jsyaml.load(this.source.val());
  } catch(err) {
    this.log("Error loading JS-YAML: " + err.message);
    this.invalidData = true;
  }
};


FormEditor.prototype.updateDataFromDom = function() {
  this.data = this.getObjectFromDom();
};

FormEditor.prototype.dom2yaml = function() {
  $("#form_content").html(json2yaml(this.getObjectFromDom()));
};

// retrieves the value from the source textarea, parses it into a JS
// object and returns it.
FormEditor.prototype.getValue = function() {
  try {
    return jsyaml.load(this.source.val());
  } catch(err) {
    this.log("Error loading JS-YAML: " + err.message);
    this.invalidData = true;
  }
};



FormEditor.prototype.getObjectFromDom = function() {
  var obj = {rubyobject: "AbstractForm"};
  $("#form_editor input, #form_editor select, #form_editor textarea").each(function(ind, elem) {
    var path = $(elem).attr("id");
    var type = $(elem).attr("type");
    // continue, as it’s a custom input element or it is hidden
    if(!path || !path.match(/^\//) || (!$(elem).is(":visible") && type != "hidden"))
      return true;

    var v = $(elem).val();
    // convert values to their proper types
    if(type == "checkbox") v = $(elem).is(":checked");
    if(type == "numeric") v = parseFloat(v);
    if($(elem).prop("tagName") == "TEXTAREA") {
      if(v == "") return true;
      v = v.split("\n");
      for(var ind in v) {
        if(v[ind] == "")
          v[ind] = null;
      }
    }

    // skip these default values
    if(path.match(/\/last_is_textbox$/) && v == "0") return true;
    if(path.match(/\/boxes\/[0-9]+\/text$/) && v == "") return true;
    if(path.match(/\/hide_answers$/) && !v) return true;
    if(path.match(/\/repeat_for$/) && v == "only_once") return true;

    FormEditor.getInstance().setPath(obj, path, v);
  });

  // post-processing required for correct type and db_column fields.
  // should be removed once the type-field has been updated (TODO). Also
  // removed "undefined" array entries which may appear due to original
  // part being deleted.
  obj["pages"] = obj["pages"].filter(function(){return true});
  $.each(obj["pages"], function(ind, page) {
    page["sections"] = page["sections"] || [];
    page["sections"] = page["sections"].filter(function(){return true});
    $.each(page["sections"], function(ind, sect) {
      sect["questions"] = sect["questions"] || [];
      sect["questions"] = sect["questions"].filter(function(){return true});
      $.each(sect["questions"], function(ind, quest) {
        switch(quest["type"]) {
          case "Single":
            quest["type"] = "square";
            break;
          case "Multi":
            quest["type"] = "square";
            var a = [];
            for(var i = 0; i < quest["boxes"].length; i++) {
              a[i] = quest["db_column"] + "_" + String.fromCharCode(97+i);
            }
            quest["db_column"] = a;
            break;
          case "Text":
            quest["type"] = "text";
            quest["boxes"] = [];
            break;
          case "Tutor":
            quest["type"] = "tutor_table";
            quest["boxes"] = null;
            break;
          default:
            throw("Unsupported question type: " + quest["type"]);
        }
      });
    });
  });
  return obj;
};


FormEditor.prototype.getAttributeByIndex = function(obj, index) {
  var i = 0;
  for (var attr in obj) {
    if (index === i){
      return obj[attr];
    }
    i++;
  }
  return null;
};



FormEditor.prototype.checkDuplicateIds = function() {
  var ids = [];
  $('[id]').each(function(){
    $F().assert(ids.indexOf(this.id) < 0, 'Multiple IDs #'+this.id);
    ids.push(this.id);
  });
};

FormEditor.prototype.setPath = function(obj, path, value) {
  $.each(path.split("/").reverse(), function(ind, elem) {
    if(elem == "") return;
    var v = value;
    if(elem.match(/^[0-9]+$/)) { // it’s an array
      value = [];
      value[parseInt(elem)] = v;
    } else { // it’s a hash
      value = {};
      value[elem] = v;
    }
  });
  return $.extend(true, obj, value);
};


FormEditor.prototype.getPath = function(path) {
  var l = path.split("/");
  this.assert("" == l.shift(), "Invalid path given. Must start with /. Given: " + path);
  var r = this.data;
  var pathok = "";
  for(var x in l) {
    r = r[l[x]];
    this.assert(r !== undefined, "Invalid path given. Element does not exist. Given path: "+path + "  Path correct for: " + pathok);
    pathok += "/" + l[x];
  }
  return r;
};

FormEditor.prototype.getDomObjFromPath = function(path) {
  return $(document.getElementById(path));
}

FormEditor.prototype.getPathDepth = function(path) {
  return path.split("/").length - 1;
};
