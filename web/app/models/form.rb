# -*- coding: utf-8 -*-
require 'pp'
require 'stringio'

class Form < ActiveRecord::Base
  belongs_to :semester
  has_many :courses
  validates_presence_of :semester, :name, :content

  alias_attribute :title, :name

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
    return false if has_duplicate_db_columns?
    return false if db_table.nil? || db_table.empty?
    return false if questions.count { |q| q.type == "tutor_table" } >= 2
    return false unless find_out_of_scope_variables.empty?

    true
  end

  # There are some variables which can be used to design the form, e.g.
  # \lect to refer to the lecturer’s name. These variables may be valid
  # for the whole sheet when the questions are used in the form. However
  # they are actually only valid for certain parts of the form. Consider
  # \lect: It can only valid for questions that depend on the lecturer
  # (i.e. repeat_for = :lecturer). Forms should support multiple
  # lecturers per course, therefore these variables cannot be used out-
  # side the correct repeat_for-scope.
  def find_out_of_scope_variables
    a = []
    questions.each do |q|
      next if !q.qtext.to_a.join.include?("\\lect") || q.repeat_for == :lecturer
      a << "Question #{q.db_column.find_common_start} appears to use \\lect* even though repeat_for is not lecturer."
    end
    sections.each do |s|
      next if !s.title.to_a.join.include?("\\lect") || s.questions.first.repeat_for == :lecturer
      a << "Section #{s.title} appears to use \\lect* even though repeat_for for the following question is not lecturer."
    end
    a
  end

  # what languages does this form support? If it's a single language form, i.e. if no strings
  # are translated :en is assumed
  def languages
    return [:en] unless abstract_form_valid?
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

  # catches all methods that are not implemented and sees if
  # AbstractForm has them. If it doesn’t either, a more detailed error
  # message is thrown.
  def method_missing(name, *args, &block)
    begin; super; rescue
      return abstract_form.method(name).call(*args) if abstract_form.respond_to?(name)
      raise "undefined method #{name} for both web/app/models/form.rb and lib/AbstractForm.rb"
    end
  end

  # tell everyone that we know about abstract_form’s methods
  def respond_to?(name)
    return true if abstract_form.respond_to?(name)
    super
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

  # returns a translated string about too few sheets being available to
  # evaluate (anonymity protection). Supports special strings for 0, 1
  # and more than 1 situations.
  def too_few_sheets(count)
    case count
      when 0: I18n.t(:too_few_questionnaires)[:null]
      when 1: I18n.t(:too_few_questionnaires)[:singular]
      else    I18n.t(:too_few_questionnaires)[:plural].gsub(/#1/, count.to_s)
    end
  end
end
