
FormEditor.prototype.parseAbstractForm = function(data) {
  var path = "";

  this.assert(data["rubyobject"] == "AbstractForm", "First entry of data is not an AbstractForm. Either the form is broken or the data subset passed is not an AbstractForm.");

  this.createAvailLangBox();

  this.createTextBox(path + "/db_table", "database table");
  this.append("<br/>");

  for(var x in data) {
    var d = this.data[x];
    if(x.match("rubyobject|pages|db_table$"))
      continue;

    this.assert($.inArray(ATTRIBUTES["AbstractForm"].x), "The given data subset contains an unknown attribute for AbstractForm: " + x + ".");

    this.createTranslateableTextBox(path + "/" + x, x);
  }

  for(var x in this.data["pages"]) {
    var page = this.data["pages"][x];
    this.parsePage(page, path + "/pages/" + x);
  }

  this.root.append(this.generatedHtml);
  this.dom2yaml();
};

FormEditor.prototype.parsePage = function(page, path) {
  this.openGroup("page");
  this.createHiddenBox(path+"/rubyobject", "Page");
  this.append('<a class="delete" onclick="$F().deletePageBreak(this)" title="Delete Page Break" style="display: none;">⌫</a>');
  for(var y in ATTRIBUTES["Page"]) {
    var attr = ATTRIBUTES["Page"][y];
    this.createTranslateableTextBox(path + "/" + attr, attr);
  }
  var sections = page["sections"];
  for(var sect in sections) {
    var section = sections[sect];
    this.parseSection(section, path + "/sections/" + sect);
  }
  this.closeGroup();
};

FormEditor.prototype.parseSection = function(section, path) {
  this.openGroup("section");
  this.append('<h5 class="header">');
  this.append('<a class="moveup" onclick="$F().moveSectionUp(this);" title="move section one block up">↑</a>');
  this.append('<a class="movedown" onclick="$F().moveSectionDown(this);" title="move section one block down">↓</a>');
  this.append('<a class="duplicate" title="Duplicate Section" onclick="$F().duplicateSection(this)">⎘</a>');
  this.append('<a class="delete" title="Delete Section" onclick="$F().deleteSection(this)">×</a>');
  this.append('</h5>');


  this.openGroup("collapsable closed");
  this.append('<h6 class="header">header details<a title="Collapse/Expand" class="collapse"></a></h6>');
  this.createHiddenBox(path+"/rubyobject", "Section");
  for(var y in ATTRIBUTES["Section"]) {
    var attr = ATTRIBUTES["Section"][y];
    this.createTranslateableTextBox(path + "/" + attr, attr);
  }
  section["answers"] = section["answers"] || [];
  this.createTranslateableTextArea(path + "/answers");
  this.closeGroup();

  var questions = section["questions"];
  this.openGroup("sortable-question", "ol");
  for(var quest in questions) {
    this.parseQuestion(questions[quest], path + "/questions/" + quest);
  }
  this.closeGroup();
  this.closeGroup();
};

FormEditor.prototype.parseQuestion = function(question, path) {
  this.openGroup("question collapsable closed", "li");
  this.append('<h6 class="header">');
  this.append('<a class="collapse" title="Collapse/Expand"></a>');
  this.append('<a class="move" title="Move/Sort (use drag and drop; hit escape to cancel)">⬍</a>');
  this.append('<a class="duplicate" title="Duplicate Question" onclick="$F().duplicateQuestion(this)">⎘</a>');
  this.append('<a class="delete" title="Delete Question" onclick="$F().deleteQuestion(this)">×</a>');
  this.append('</h6>');
  this.createHiddenBox(path+"/rubyobject", "Question");
  this.createTranslateableTextBox(path + "/qtext", "qtext");
  var isMulti = this.isQuestionMulti(question);
  // TODO: fix how type works elsewhere and merge with multi-choice
  var typeTranslation = {"square": "Single", "tutor_table": "Tutor", "text": "Text" };
  question["type"] = isMulti ? "Multi" : typeTranslation[question["type"]];
  question["repeat_for"] = question["repeat_for"] || "only_once";
  if(isMulti) {
    var c = question["db_column"][0];
    question["db_column"] = c.substr(0, c.lastIndexOf("_"));
  }

  this.createSelectBox(path + "/type", "type", Object.keys(ATTRIBUTES["Visualizers"]), true, "", "questionTypeChanged");
  this.createTextBox(path + "/db_column", "db_column", true, "db_column");

  // these boxes depend on the question type. They are created in HTML
  // but may be hidden. Their values are discarded when generating the
  // final YAML, but they are present in the JS-data structure.
  this.createHideAnswersBox(question, path);
  this.createLastIsTextBox(question, path);
  this.createHeightBox(question, path);

  var vis = ATTRIBUTES["Visualizers"][question["type"]];
  this.createSelectBox(path + "/visualizer", "visualizer", vis, true);
  this.createSelectBox(path + "/repeat_for", "repeat_for", ["only_once", "lecturer", "tutor"], true);

  this.parseBoxes(question, path);
  this.closeGroup();
};


FormEditor.prototype.parseBoxes = function(question, path) {
  this.createHeading(path + "/boxes");
  for(var ind in question["boxes"]) {
    var bpath = path + "/boxes/" + ind;
    var box = question["boxes"][ind];
    box["text"] = box["text"] || "";
    this.createHiddenBox(bpath + "/rubyobject", "Box");
    this.createTranslateableTextBox(bpath + "/text");
  }
  this.createActionLink("$F().createNewBox(this)", "Create Additional Box");
  this.append(" | ");
  this.createActionLink("$F().removeLastBox(this)", "Remove Last Box");
  this.closeHeading();
};
