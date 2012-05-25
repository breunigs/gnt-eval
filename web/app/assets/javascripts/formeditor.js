function FormEditor() {
  this.source = $('#form_content');
  this.root = $('#form_editor');
  this.data = this.getValue();
  this.invalidData = false;

  this.parseAbstractForm(this.data, "/");
}

FormEditor.prototype.parseAbstractForm = function(data, path) {
  if(data["rubyobject"] != "AbstractForm")
    throw("First entry of data is not an AbstractForm. Either the form is broken or the data subset passed is not an AbstractForm.");

  // this variable will hold the currently processed subtree
  this.subtree = data;

  this.createTextBox(path, "db_table");

  for(var x in data) {
    var d = this.data[x];
    if(x.match("rubyobject|pages|db_table$"))
      continue;

    if(!$.inArray(ATTRIBUTES["AbstractForm"].x))
      throw("The given data subset contains an unknown attribute for AbstractForm: " + x + ".");

    //~ if(typeof(d) == "string")
    this.createTranslateableTextBox(x);
    //~ else
      //~ this.log(x + ": " + typeof(d));
  }

  // handle pages here
};

FormEditor.prototype.createTranslateableTextBox = function(path, name) {
  var lang = [];
  if(typeof this.data[path] === "string") {
    this.createTextBox(path, "texhead");
  } else {
    for(var x in this.data) {
      var lang = x, translation = this.data[x];

      this.assert(lang.length == 2, "Language Code must be two letters long. Given: "+lang+": "+translation);
      this.createTextBox(path+name, lang.toLowerCase);
    }
  }
};

// creates a textbox for a single value that is not translatable.
FormEditor.prototype.createTextBox = function(path, name) {
  if(path === undefined)
    throw("Given path is invalid.");
  if(name === undefined)
    throw("Given field name is invalid.");

  // create unique ID for this element. It’s required for GUI uses only,
  // so we can add a random string to avoid collisions without storing
  // it for later.
  var id = path + name + "|" + Math.random();
  this.root.append('<label for="'+id+'">'+name+'</label>');
  this.root.append('<input type="text" name="'+path+name+'" id="'+id+'" value="'+this.subtree[name]+'"/>');
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
