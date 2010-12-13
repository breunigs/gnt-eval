# -*- coding: utf-8 -*-
# = AbstractForm.rb - Everything you need to have an abstract form
#
# Contains the following classes:
# - AbstractForm: Basic class containing pages and dbtable
# - Page: Containing list of questions on that particular page
# - Question: see class.
# - Box: see class
#

require 'pp'

# This is a box on a printed form. Nothing more.
# Especially, attributes such es width or x,y-positions are added to
# this class elsewhere.
class Box

  # value to insert into database if cross is here
  attr_accessor :choice

  # what is the _meaning_ of this box
  attr_accessor :text

  # special value for easier LaTeX sheet generation, e.g. square or comment
  attr_accessor :type

  # if this i a comment field, we need to know its height
  attr_accessor :height

  def initialize(c, t)
    @choice = c
    @text = t
  end
end

# This is a question on a printed form. Nothing more.
class Question
  # list of boxes
  attr_accessor :boxes

  # text of the question
  attr_accessor :qtext

  # value to insert into database if OMR fails
  attr_accessor :failchoice

  # value to insert into db if there is no mark
  attr_accessor :nochoice

  # what does the box look like (defaults to square)
  attr_accessor :type

  # into which field to write the result (use a list for multiple choice questions!)
  attr_accessor :db_column

  # postfix when saving file
  attr_accessor :save_as

  # special care: boolean, true falls extra liebe benoetigt wird
  # (tutoren, studienfach, semesterzahl)

  attr_accessor :special_care
  attr_accessor :donotuse

  def initialize(boxes = [], qtext='', failchoice=-1,
                 nochoice=nil, type='square', db_column='', save_as = '')

    @boxes = boxes
    @qtext = qtext
    @failchoice = failchoice
    @nochoice = nochoice
    @type = type
    @db_column = db_column
    @save_as = save_as
  end

  # how many choices are there?
  def size
    return @boxes.count
  end

  # belongs to: 'tutor', 'prof', 'uebungsgruppenbetrieb'
  # FIXME: now questions belong to sections. is there a way we could …
  def section
    if @db_column.nil? || @special_care == 1
      return 'this is no question in a traditional sense'
    end
    first_letter = (@db_column.to_s)[0].chr
    if first_letter == 'v'
      return 'prof'
    elsif first_letter == 't'
      return 'tutor'
    elsif first_letter == 'u'
      return 'uebungsgruppenbetrieb'
    end
  end

  # is the question active?
  def active?
    if not @active.nil?
      return true
    else
      return false
    end
  end

  # for compatibility reasons
  def saveas
    @save_as
  end

  # leftmost choice in appropriate language
  def ltext(language = :en)
    @boxes.first.text[language]
  end

  # rightmost choice in appropriate language
  def rtext(language = :en)
    @boxes.last.text[language]
  end

  # collect all possible choices and return as array
  def get_choices(language = nil)
    if language.nil?
      @boxes.collect { |x| x.text.nil? ? '' : x.text }
    else
      @boxes.collect { |x| x.text.nil? ? '' : x.text[language] }
    end
  end

  # question itself in appropriate language
  def text(language = :en)
    @qtext[language]
  end

  # did the user fail to answer the question?
  def failed?
    return @value == @failchoice
  end

  # didn't the user make any choice?
  def nochoice?
    return @value == @nochoice || (@value == 0 && @nochoice.nil?)
  end

  # is this a multi-answer question?
  def multi?
    return @db_column.is_a?(Array)
  end

  # export a single question to tex
  def to_tex
    #     \qvm{Gibt es Probleme mit dem mündlichen Vortrag? Wenn ja, welche?}{
    # keine}{zu leiss
    # e Verstärkeranlage}{mangelnde Sprachkenntnisse}{Studis zu
    # laut}{sonstige}{v18}

    # hier könnte ein echter algorithmus hin
    # FIXME: kommentarfelder

    unless @special_care
      '\q' + ['i','ii','iii','iv','v','vi'][@boxes.count-1] +
        (multi? ? 'm' : '') +  '{' + text + '}' + boxes.map{|b| '{' +
        b.text.to_s + '}'}.join('') + '{' + tex_db_column + '}' +
        "\n\n"
    else
      ''
    end
  end

  def tex_db_column
    if multi?
      c = @db_column.first
      c[0,c.length-1]
    else
      @db_column
    end
  end

  include FunkyDBBits

  # h: hash correspoding to specific (!) where clause
  # g: hash corresponding to general (!) where clause
  def eval_to_tex(h, g, db_table, language)
    @db_table = db_table

    b = ''

    if @db_column.is_a?(Array)

      answers = multi_q(h, self, language)

      t = TeXMultiQuestion.new(text(language), answers)
      b << t.to_tex

      # single-q
    else
      antw, anz, m, m_a, s, s_a = single_q(h, g, self)
      if anz > 0
        t = TeXSingleQuestion.new(text(language), ltext(language), rtext(language), antw,
                                  anz, m, m_a, s, s_a)

      b << t.to_tex
      end
    end
    return b
  end

end


# this is atm actually just needed for OMR/TeX to distinguish between
# pages. maybe (future ...) we could differentiate between different
# types of questions.
#
class Section
  attr_accessor :title
  attr_accessor :questions
  def initialize(t ='', q=[])
    @title = t
    @questions = q
  end
end

# this is really just needed for tex and OMR
class Page

  # list of sections on that page
  attr_accessor :sections
  attr_accessor :tex_at_top
  attr_accessor :tex_at_bottom

  def initialize(secs=[])
    @sections = secs
  end
  def questions
    if @sections.nil?
      @questions
    else
      @sections.collect {|s| s.questions}.flatten
    end
  end
end


# main form, list of pages and dbtable.
#

class AbstractForm

  # list of pages
  attr_accessor :pages

  # database table to use for this form
  attr_accessor :db_table

  # we differentiate gender here
  attr_accessor :lecturer_header

  # FIXME: is this correct? or should this be I18n-magic? this is a
  # bit difficult, but better be safe than sorry and leave it here.
  attr_accessor :study_groups_header
  attr_accessor :study_groups_overview
  attr_accessor :study_groups_overview_header

  attr_accessor :texhead
  attr_accessor :texfoot

  def initialize(pages = [], db_table = '')
    @pages = pages
    @db_table = db_table
  end

  # direct access to questions
  def questions
    @pages.collect { |p| p.questions }.flatten
  end

  # find the question-object belonging to a db_column
  def get_question(db_column)
    questions.find { |q| q.db_column == db_column }
  end

  # pretty printing an AbstrctForm is a bit gnaahaha
  # this does NOT stout but returns a string
  def pretty_print
    orig = $stdout
    sio = StringIO.new
    $stdout = sio
    pp self
    $stdout = orig

    # aber bitte ohne die ids und ohne @
    sio.string.gsub(/0x[^\s]*/,'').gsub(/@/,'')
  end
end

