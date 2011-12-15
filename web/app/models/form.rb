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

  # returns true iff the form is a valid AbstractForm class. Nothing else is checked.
  def abstract_form_valid?
    abstract_form.is_a? AbstractForm
  end

  # runs all kinds of checks to see if the form is fine and ready to be used in the wild.
  # currently checks: AbstractForm is valid; no duplicate db_columns
  def form_checks_out?
    return false unless abstract_form_valid?
    return false if abstract_form.has_duplicate_db_columns?
    return false if db_table.nil? || db_table.empty?

    true
  end

  # what languages does this form support? If it's a single language form, i.e. if no strings
  # are translated :en is assumed
  def languages
    l = questions.collect { |q| (q.qtext.is_a?(Hash) ? q.qtext.keys : nil) }.flatten.compact.uniq
    (l.nil? || l.empty?) ? [:en] : l
  end

  def has_language? lang
    languages.include? lang.to_sym
  end

  # returns list of db dolumn names that are used more than once and the offending questions.
  # returns empty hash if there aren’t any duplicates and something like this, if there are:
  # { :offending_column => ["Question 1?", "Question 2?"] }
  def get_duplicate_db_columns
    return {} unless abstract_form_valid?
    abstract_form.get_duplicate_db_columns
  end

  # returns true if there are any db columns used more than once
  def has_duplicate_db_columns?
    return false unless abstract_form_valid?
    !abstract_form.get_duplicate_db_columns.empty?
  end

  # FIX: this should be method-missing-magic, but that is a bit complicated for reasons unknown
  def db_table
    abstract_form.is_a?(AbstractForm) ? abstract_form.db_table : nil
  end
  def questions
    abstract_form.is_a?(AbstractForm) ? abstract_form.questions : []
  end
  def lang
    abstract_form.is_a?(AbstractForm) ? abstract_form.lang : nil
  end
  def pages
    abstract_form.is_a?(AbstractForm) ? abstract_form.pages : []
  end
  def texheadnumber
    abstract_form.texheadnumber
  end

  # return a string like "Introduction to Astrophysics by John Doe"
  def lecturer_header(fullname, gender, language, sheets)
    h = abstract_form.lecturer_header
    # if the desired lang/gender isn't available, try english/neutral
    # next. If that fails as well, take whatever comes first.
    h = h[language] || h[:en] || h.first[1]
    h = h[gender] || h[:both] || h.first[1]
    h.gsub(/#1/, fullname).gsub(/#2/, sheets.to_s)
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
