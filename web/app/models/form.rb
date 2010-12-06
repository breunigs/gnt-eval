# -*- coding: utf-8 -*-
require 'pp'
require 'stringio'

class Form < ActiveRecord::Base
  belongs_to :semester
  has_many :course

  def abstract_form
    YAML::load(content)
  end
  def pretty_abstract_form
    orig = $stdout
    sio = StringIO.new
    $stdout = sio
    pp abstract_form
    $stdout = orig

    # aber bitte ohne die ids und ohne @
    sio.string.gsub(/0x[^\s]*/,'').gsub(/@/,'')
  end

  # fix: das sollte method_missing-magie werden
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
end
