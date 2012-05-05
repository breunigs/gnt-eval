function FormEditor() {
  this.source = $('form_content');
  this.root = $('form_editor');
  this.data = this.getValue();

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
    if(x.endsWith("rubyobject") || x.endsWith("pages") || x.endsWith("db_table"))
      continue;

    if(!ATTRIBUTES["AbstractForm"].include(x))
      throw("The given data subset contains an unknown attribute for AbstractForm: " + x + ".");

    //~ if(typeof(d) == "string")
    this.createTranslateableTextBox(x);
    //~ else
      //~ this.log(x + ": " + typeof(d));
  }

  // handle pages here
};

FormEditor.prototype.createTranslateableTextBox = function(path, name) {
  //~ if(type == undefined || type == null)
    //~ type = "text";

  this.root.insert('<p>text'+path+':  '+this.data[path]+'</p>');
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
  this.root.insert('<label for="'+id+'">'+name+'</label>');
  this.root.insert('<input type="text" name="'+path+name+'" id="'+id+'" value="'+this.subtree[name]+'"/>');
};

// retrieves the value from the source textarea, parses it into a JS
// object and returns it.
FormEditor.prototype.getValue = function() {
  try {
    return jsyaml.load(this.source.value);
  } catch(err) {
    this.log(err.toString());
  }
};

// log to Firebug and the like if available
FormEditor.prototype.log = function(strng) {
  if(window.console) console.log(strng);
};
