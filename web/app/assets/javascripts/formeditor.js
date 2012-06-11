function FormEditor() {
  this.source = $('#form_content');
  this.root = $('#form_editor');
  this.data = this.getValue();
  this.invalidData = false;
  this.generatedHtml = "";

  this.parseAbstractForm(this.data, "");
}

FormEditor.prototype.append = function(content) {
  this.generatedHtml += content + "\n";
}

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

  this.log(this.generatedHtml);
  this.root.append(this.generatedHtml);
};

FormEditor.prototype.createHeading = function(path) {
  var last = path.split("/").pop();
  this.append('<span>'+last+'</span><div class="indent">');
}

FormEditor.prototype.createTranslateableTextBox = function(path) {
  var lang = [];
  var texts = this.getPath(path);
  //this.log("Creating translateable textbox at: " + path + " " + name);
  if(typeof(texts) == "string") {
    this.createTextBox(path, path.split("/").pop());
    // TODO: translate link
  } else {
    this.createHeading(path);
    for(var lang in texts) {
      var newPath = path+"/"+lang;
      this.assert(lang.match(/^:[a-z][a-z]$/), "Language Code must be in the :en format. Given lang: "+lang);
      if(typeof(texts[lang] ) == "string") {
        this.createTextBox(newPath, lang.toLowerCase());
        // TODO: genderize link
      } else {
        this.createHeading(newPath);
        this.createTextBox(newPath + "/:both", "neutral");
        this.createTextBox(newPath + "/:female", "female");
        this.createTextBox(newPath + "/:male", "male");
        this.append("</div>");
      }
    }
    this.append('</div>');
  }
};

// creates a textbox for a single value that is not translatable.
FormEditor.prototype.createTextBox = function(path, label) {
  if(path === undefined)
    throw("Given path is invalid.");
  if(label === undefined)
    throw("Given label is invalid.");

  //this.assert(typeof(this.getPath(path)) == "string", "Content for textbox is not a string. Given path: " + path);

  // create unique ID for this element. It’s required for GUI uses only,
  // so we can add a random string to avoid collisions without storing
  // it for later.
  var id = path + "|" + Math.random();
  this.append('<label for="'+id+'">'+label+'</label>');
  this.append('<input type="text" title="'+path+'" id="'+id+'" value="'+this.getPath(path)+'"/>');
  this.append('<br/>');
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
