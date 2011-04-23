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
  def abstract_form
    # cache yaml files for speeeed
    $loaded_yaml_sheets ||= {}
    $loaded_yaml_sheets[id] ||= YAML::load(content)
    $loaded_yaml_sheets[id]
  end

  # pretty printing an AbstrctForm is a bit
  def pretty_abstract_form
    if abstract_form.is_a? String
      "This is not a valid form. Here's the source: \n\n\n" + abstract_form.to_s
    else
      abstract_form.pretty_print_me
    end
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
    abstract_form.db_table
  end
  def questions
    abstract_form.questions
  end
  def lang
    abstract_form.lang
  end
  def pages
    abstract_form.pages
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
    I18n.locale = language
    I18n.load_path += Dir.glob(File.join(Rails.root, '/config/locales/*.yml'))

    if sheets == 0
      I18n.t(:too_few_questionnaires)[:null]
    elsif sheets == 1
      I18n.t(:too_few_questionnaires)[:singular]
    else
      I18n.t(:too_few_questionnaires)[:plural].gsub(/#1/, sheets.to_s)
    end
  end

  def study_groups_overview_header(lang)
    abstract_form.study_groups_overview_header[lang]
  end

  def study_groups_overview(lang)
    abstract_form.study_groups_overview[lang]
  end

  def study_groups_header(lang)
    abstract_form.study_groups_header[lang]
  end
end
