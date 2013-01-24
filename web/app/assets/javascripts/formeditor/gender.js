/* Gendering is split up into :neutral, :female and :male and if a field
 * is gendered all of these must be provided. Not all fields support
 * gendering.
 *
 * Gendering depends on either the lecturer or the tutor¹. However,
 * latter is only available in the results and not in the sheets because
 * the tutors are selected via checkmark on the sheet. It’s a really
 * good idea to have repeat_for set correctly so GnT-Eval knows which
 * gender to look for.
 *
 * ¹ Tutors have no gender manually specified as of writing. Instead,
 *   their gender is guessed based on their first name.*/

/* @public
 * Genderizes a given path. It therefore updates the data object from
 * the current DOM. This way the common functions to generate the text
 * boxes and action links may be used.
 * @param caller  The element which issues the call. Required if the
 *                non-genderized text box should be replaced with the
 *                new version. The select rule is rather complicated,
 *                but it works for the default links. */
FormEditor.prototype.genderizePath = function(caller) {
  var path = $(caller).prev().attr('id');
  this.updateDataFromDom();
  this.addUndoStep("genderizing " + path);

  // generate new object
  var oldText = this.getPath(path);
  var genderized = { ":male": oldText, ":female": oldText, ":both": oldText};

  // inject new object
  this.setPath(this.data, path, genderized);

  // update dom
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).closest(".heading:not(.language)").replaceWith(this.generatedHtml);
};

/* @public
 * Works just like genderizePath, but the other way round. See there
 * for details. */
FormEditor.prototype.ungenderizePath = function(caller) {
  var path = $(caller).parent().attr('id');
  this.addUndoStep("un-gendering " + path);
  this.updateDataFromDom();

  var oldText = this.getPath(path + "/:both");
  // inject new object
  this.setPath(this.data, path, oldText);
  path = path.split("/").slice(0, -1).join("/");
  this.generatedHtml = "";
  this.createTranslateableTextBox(path);
  $(caller).closest(".heading:not(.language)").replaceWith(this.generatedHtml);
};
