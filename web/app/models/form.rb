# -*- coding: utf-8 -*-
require 'pp'
require 'stringio'

class Form < ActiveRecord::Base
  belongs_to :semester
  has_many :courses
  validates_presence_of :semester, :name, :content

  # returns if the form is critical. This is the case if the semester is
  # critical. It may be edited/removed even if there are associated
  # courses. Latter would not be too wise, though.
  def critical?
    semester.critical?
  end

  # the AbstractForm object belonging to this form
  # this is NOT relational, we just dump the AbstractForm into the database as a YAML-string
  # expiring will be handled in the forms_controller#expire_cache
  def abstract_form
    # cache yaml files for speeeed
    $loaded_yaml_sheets ||= {}
    begin
      $loaded_yaml_sheets[id] ||= YAML::load(content)
    rescue Exception => e
      # Sheet does not appear to be a valid YAML. In this case the
      # value will be nil (and thus not an AbstractForm). This will
      # later be picked up as an invalid form.
      $loaded_yaml_sheets[id] = e.message + "\n\n\n" + e.backtrace.inspect
    end
    $loaded_yaml_sheets[id]
  end

  # pretty printing an AbstrctForm is a bit tricky
  def pretty_abstract_form
    if abstract_form_valid?
      abstract_form.pretty_print_me
    else
      "This is not a valid form. Here's what could be parsed: \n\n\n" + PP.pp(abstract_form, "")
    end
  end

  def abstract_form_valid?
    abstract_form.is_a? AbstractForm
  end

  # what languages does this form support?
  def languages
    questions.collect { |q| q.qtext.keys }.uniq.flatten
  end

  def has_language? lang
    languages.include? lang.to_sym
  end

  # FIX: this should be method-missing-magic, but that is a bit complicated for reasons unknown
  def db_table
    abstract_form ? abstract_form.db_table : nil
  end
  def questions
    abstract_form ? abstract_form.questions : []
  end
  def lang
    abstract_form ? abstract_form.lang : nil
  end
  def pages
    abstract_form ? abstract_form.pages : []
  end
  def texheadnumber
    abstract_form.texheadnumber
  end

  # return a string like "Introduction to Astrophysics by John Doe"
  def lecturer_header(fullname, gender, language, sheets)
    abstract_form.lecturer_header[language][gender].gsub(/#1/, fullname).gsub(/#2/, sheets.to_s)
  end

  def get_question(search)
    abstract_form.get_question(search)
  end

  # if too few questionnaires have been submitted, we return a lovely statement about anonymity etc.
  def too_few_questionnaires(language, sheets)
    # only set locale if we want a mixed-lang document
    I18n.locale = language if I18n.tainted?

    if sheets == 0
      I18n.t(:too_few_questionnaires)[:null]
    elsif sheets == 1
      I18n.t(:too_few_questionnaires)[:singular]
    else
      I18n.t(:too_few_questionnaires)[:plural].gsub(/#1/, sheets.to_s)
    end
  end
end
