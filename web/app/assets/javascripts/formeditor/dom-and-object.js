/* Hosts functions that allow dealing with the JS Object representation
 * of the abstract form as well as conversion both from and to the YAML
 * and DOM one. */

/* @public
 * Reads YAML data from original textarea and returns JS object if it
 * worked.
 * @returns AbstactForm as JS Object */
FormEditor.prototype.getValue = function() {
  try {
    return jsyaml.load($('#form_content').val());
  } catch(err) {
    this.log("Error loading JS-YAML: " + err.message);
    this.invalidData = true;
  }
};

/* @public
 * Updates the internal representation of the AbstractForm by reading
 * all elements from the DOM */
FormEditor.prototype.updateDataFromDom = function() {
  this.data = this.getObjectFromDom();
};

/* @public
 * Updates the original textarea with the AbstractForm as currently
 * represented by the DOM elements. Auto-converts it to YAML. */
FormEditor.prototype.dom2yaml = function() {
  $("#form_content").html(json2yaml(this.getObjectFromDom()));
};


/* @public
 * Retrieves the first element of an object and returns its value.
 * @param object
 * @return value if anything is found, null otherwise */
FormEditor.prototype.getAnyElement = function(obj, index) {
  for (var attr in obj) {
    if (obj.hasOwnProperty(i) && typeof(i) !== 'function') {
      return obj[attr];
    }
  }
  return null;
};

/* @public
 * Method ensures that there are no duplicate IDs in the form editor.
 * If that happens, it’s not clear how the YAML generated from that
 * would look like, so this function throws if a duplicate ID is
 * encountered. */
FormEditor.prototype.checkDuplicateIds = function() {
  var ids = [];
  $('[id]').each(function(){
    $F().assert(ids.indexOf(this.id) < 0, 'Multiple IDs #'+this.id);
    ids.push(this.id);
  });
};

/* @public
 * Updates data for a given path. Also needs to be given JS object to
 * write to; it doesn’t simply use the global data variable.
 * @param AbstractForm as JS Object which to update
 * @param path that should be updated
 * @param value to write */
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
  $.extend(true, obj, value);
};

/* @public
 * Retrieves the data for the given path that is stored in the form
 * editor’s data variable, i.e. the JS Object representation of the
 * form. Throws if an invalid path is given.
 * @param path to retrieve data for
 * @returns JS Object for that path */
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

/* @public
 * Returns jQuery-fied element that belongs to the given path. Works
 * just like jQuery’s $('#id") except that it has no problems with
 * slashes.
 * @param path for which to retrieve the element
 * @returns jQuery-fied element (or empty array if path does not exist)
 * */
FormEditor.prototype.getDomObjFromPath = function(path) {
  return $(document.getElementById(path));
}

/* @private
 * Reads each (DOM) input field in the form editor and constructs a
 * JS object representation of the AbstractForm. May apply magic to
 * make that object easier to handle for follow up methods.
 * @returns AbstractForm JS Object */
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

    $F().setPath(obj, path, v);
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
