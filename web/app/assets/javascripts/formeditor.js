function FormEditor() {
  // singleton, via http://stackoverflow.com/a/6876814
  if(arguments.callee.instance)
    return arguments.callee.instance;
  arguments.callee.instance = this;


  this.source = $('#form_content');
  this.root = $('#form_editor');
  this.data = this.getValue();
  this.invalidData = false;
  this.generatedHtml = "";

  this.parseAbstractForm(this.data, "");
}

FormEditor.getInstance = function() {
  var fe = new FormEditor();
  return fe;
};


FormEditor.prototype.append = function(content) {
  this.generatedHtml += content + "\n";
};

FormEditor.prototype.getPath = function(path) {
  var l = path.split("/");
  this.assert("" == l.shift(), "Invalid path given. Must start with /. Given: " + path);
  var r = this.data;
  for(var x in l) {
    r = r[l[x]];
    this.assert(r !== undefined, "Invalid path given. Element does not exist. Given path: "+path);
  }
  return r;
};

FormEditor.prototype.getPathDepth = function(path) {
  return path.split("/").length - 1;
};

FormEditor.prototype.parseAbstractForm = function(data, path) {
  if(data["rubyobject"] != "AbstractForm")
    throw("First entry of data is not an AbstractForm. Either the form is broken or the data subset passed is not an AbstractForm.");

  this.createTextBox(path + "/db_table", "database table");
  this.append("<br/>");

  for(var x in data) {
    var d = this.data[x];
    if(x.match("rubyobject|pages|db_table$"))
      continue;

    if(!$.inArray(ATTRIBUTES["AbstractForm"].x))
      throw("The given data subset contains an unknown attribute for AbstractForm: " + x + ".");

    //~ if(typeof(d) == "string")
      this.log(x + ": " + path);
    this.createTranslateableTextBox(path + "/" + x, x);
    //~ else
  }

  // handle pages here

  this.createActionLink("FormEditor.getInstance().dom2yaml();", "dom 2 yaml");

  //this.log(this.generatedHtml);
  this.root.append(this.generatedHtml);
  this.dom2yaml();
};

FormEditor.prototype.setPath = function(obj, path, value) {
  $.each(path.split("/").reverse(), function(ind, elem) {
    if(elem == "") return;
    var v = value;
    value = {};
    value[elem] = v;
  });
  return $.extend(true, obj, value);
};

FormEditor.prototype.genderizePath = function(path, caller) {
  // generate new object
  var oldText = this.getPath(path);
  var genderized = { ":male": oldText, ":female": oldText, ":both": oldText};

  // update obj from dom and inject new object
  this.data = this.getObjectFromDom();
  this.setPath(this.data, path, genderized);
  //~ console.log(this.data);

  // update dom
  console.log(path);
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).parent().parent().parent().html(this.generatedHtml);
  //~ console.log();
};

FormEditor.prototype.ungenderizePath = function(path, caller) {
  var warn = false;
  var txt = null;
  $(caller).parent().find("input").each(function(ind, elm) {
    if(txt != $(elm).val() && txt != null) {
      warn = true;
      return false; // break
    }
    txt = $(elm).val();
  });
  if(warn && !confirm("The genderized texts differ. Do you want to continue and only keep the neutral one?"))
    return false;

  var oldText = this.getPath(path + "/:both");
  // update obj from dom and inject new object
  this.data = this.getObjectFromDom();
  this.setPath(this.data, path, oldText);
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).closest(".meaningless_group").html(this.generatedHtml);
};

FormEditor.prototype.getObjectFromDom = function() {
  var obj = {rubyobject: "AbstractForm"};
  $("#form_editor input").each(function(ind, elem) {
    FormEditor.getInstance().setPath(obj, $(elem).attr("title"), $(elem).val());
  });
  return obj;
};

FormEditor.prototype.dom2yaml = function() {
  $("#result").html(json2yaml(this.getObjectFromDom()));
};

FormEditor.prototype.createHeading = function(path) {
  var last = path.split("/").pop();
  this.append('<div class="heading"><span>'+last+'</span><div class="indent">');
};

FormEditor.prototype.closeHeading = function(path) {
  this.append("</div></div>");
};

FormEditor.prototype.createActionLink = function(action, name) {
  if(action.indexOf('"') >= 0)
    action = "eval(unescape('"+escape(action)+"'))"; // work around quotation marks
  this.append("<a onclick=\""+action+"\">"+name+"</a>");
};

FormEditor.prototype.openGroup = function() {
  this.append("<div class=\"meaningless_group\">");
};

FormEditor.prototype.closeGroup = function() {
  this.append("</div>");
};

// Checks if at least one of the given translations has gendering
FormEditor.prototype.translationsHaveGendering = function(texts) {
  for(var lang in texts) {
    if(typeof(texts[lang]) != "string")
      return true;
  }
  return false;a
};

FormEditor.prototype.createTranslateableTextBox = function(path) {
  var lang = [];
  var texts = this.getPath(path);

  //this.log("Creating translateable textbox at: " + path + " " + name);

  this.openGroup();
  if(typeof(texts) == "string") {
    this.openGroup();
    this.createTextBox(path, path.split("/").pop());
    this.createActionLink("action", "Translate »");
    this.closeGroup();
  } else {
    this.createHeading(path);
    if(!this.translationsHaveGendering(texts))
      this.createActionLink("action", "« Unify (no localization)");
    for(var lang in texts) {
      var newPath = path+"/"+lang;
      this.assert(lang.match(/^:[a-z][a-z]$/), "Language Code must be in the :en format. Given lang: "+lang);
      if(typeof(texts[lang] ) == "string") {
        this.openGroup();
        this.createTextBox(newPath, lang);
        this.createActionLink("FormEditor.getInstance().genderizePath(\""+path+"/"+lang+"\", this)", "Genderize »");
        this.closeGroup();
      } else {
        this.createHeading(newPath);
        this.createActionLink("FormEditor.getInstance().ungenderizePath(\""+path+"/"+lang+"\", this)", "« no gender");
        this.createTextBox(newPath + "/:both", "neutral", true);
        this.createTextBox(newPath + "/:female", "female", true);
        this.createTextBox(newPath + "/:male", "male", true);
        this.closeHeading();
      }
    }
    this.closeHeading();
  }
  this.closeGroup();
};

// creates a textbox for a single value that is not translatable.
FormEditor.prototype.createTextBox = function(path, label, group) {
  if(path === undefined)
    throw("Given path is invalid.");
  if(label === undefined)
    throw("Given label is invalid.");

  //this.assert(typeof(this.getPath(path)) == "string", "Content for textbox is not a string. Given path: " + path);

  if(group) this.openGroup();

  // create unique ID for this element. It’s required for GUI uses only,
  // so we can add a random string to avoid collisions without storing
  // it for later.
  var id = path + "|" + Math.random();
  this.append('<label for="'+id+'">'+label+'</label>');
  this.append('<input type="text" title="'+path+'" id="'+id+'" value="'+this.getPath(path)+'"/>');

  if(group) this.closeGroup();
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

// log to Firebug and the like if available
FormEditor.prototype.log = function(strng) {
  if(window.console) console.log(strng);
};

FormEditor.prototype.assert = function(expression, message) {
  if (!expression) {
    this.invalidData = true;
    throw(message);
  }
};
