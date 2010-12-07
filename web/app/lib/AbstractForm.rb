# -*- coding: utf-8 -*-
# = AbstractForm.rb - Everything you need to have an abstract form
#
# Contains the following classes:
# - AbstractForm: Basic class containing pages and dbtable
# - Page: Containing list of questions on that particular page
# - Question: see class.
# - Box: see class
#
# We won't do no eval stuff in here, this is _just_ the abstract
# notion of a form!


# This is a box on a printed form. Nothing more.
class Box

  # value to insert into database if cross is here
  attr_accessor :choice

  # what is the _meaning_ of this box
  attr_accessor :text

  # special value for easier LaTeX sheet generation, e.g. square or comment
  attr_accessor :type

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

  # leftmost choice
  def ltext
    @boxes.first.text
  end

  #rightmost choice
  def rtext
    @boxes.last.text
  end

  # collect all possible choices and return as array
  def get_choices
    @boxes.collect { |x| x.text.nil? ? '' : x.text }
  end

  # question itself
  def text
    @qtext
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

  # ausgabe einer einzelnen frage ans tex
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
  def eval_to_tex(h, g, db_table)
    @db_table = db_table

    b = ''

    if @db_column.is_a?(Array)

      answers = multi_q(h, self)

      t = TeXMultiQuestion.new(@qtext, answers)
      b << t.to_tex

      # single-q
    else
      antw, anz, m, m_a, s, s_a = single_q(h, g, self)
      if anz > 0
        t = TeXSingleQuestion.new(text, ltext, rtext, antw,
                                  anz, m, m_a, s, s_a)

      b << t.to_tex
      end
    end
    return b
  end

end


# this is actually just needed for OMR/TeX to distinguish between
# pages
#
class Section
  attr_accessor :title
  attr_accessor :questions
  def initialize(t ='', q=[])
    @title = t
    @questions = q
  end
end

class Page

  # list of sections on that page
  attr_accessor :sections
  attr_accessor :tex_at_top
  attr_accessor :tex_at_bottom

  def initialize(secs=[])
    @sections = secs
  end
  def questions
    @sections.collect {|s| s.questions}.flatten
  end
end


# main form, list of pages and (ATM) dbtable.
#

class AbstractForm

  # list of pages
  attr_accessor :pages

  # database table to use for this form
  attr_accessor :db_table

  attr_accessor :lang_quest_for_vorl_m
  attr_accessor :lang_quest_for_vorl_f
  attr_accessor :lang
  attr_accessor :texhead
  attr_accessor :texfoot
  attr_reader :english

  def initialize(pages = [], db_table = '')
    @pages = pages
    @db_table = db_table
  end

  # direct access to questions
  def questions
    @pages.collect { |p| p.questions }.flatten
  end

  def get_question(db_column)
    questions.find { |q| q.db_column == db_column }
  end

  # FIXME kill this
  def isEnglish?
    return (not (@english.nil? || @english.to_s != "1"))
  end

  def getLecturerHeader(name, gender, sheetsCount)
    if gender == 0 # Note: same as in database
      @lang_quest_for_vorl_f.gsub(/#1/, name).gsub(/#2/, sheetsCount.to_s)
    else
      @lang_quest_for_vorl_m.gsub(/#1/, name).gsub(/#2/, sheetsCount.to_s)
    end
  end

  def getStudyGroupsHeader
    self.isEnglish? ? "Questions concerning the study groups" : "Fragen zum Übungsbetrieb"
  end

  def getStudyGroupsOverview
    self.isEnglish? ? "Overview of study groups" : "Übersicht der Übungsgrupppen"
  end

  def getStudyGroupsOverviewHeader
    self.isEnglish? ? "Tutors & Questionnaires & Page" : "Tutor & Bögen & Seite"
  end

  def getSheetCount
    self.isEnglish? ? "submitted questionnaires" : "abgegebene Fragebögen"
  end

    # naming convention

  alias :is_english? :isEnglish?
  alias :lecturer_header :getLecturerHeader
  alias :study_groups_header :getStudyGroupsHeader
  alias :study_groups_overview :getStudyGroupsOverview
  alias :study_groups_overview_heades :getStudyGroupsOverviewHeader
  alias :sheet_count :getSheetCount

  def getNoQuestionnaires
    self.isEnglish? \
      ? "No questionnaires have been submitted." \
      : "Es wurden keine Fragebögen abgegeben."
  end

  def getTooFewQuestionnaires(c)
    return self.getNoQuestionnaires if c == 0

    self.isEnglish? \
      ? "Only #{c} questionnaire#{c==1? 's':''} have been submitted. In order to retain the participant#{c==1? '’s':'s’'} anonymity the results have been excluded." \
      : "Es wurde#{c==1? '':'n'} nur #{c} Frage#{c==1? 'bogen':'bögen'} abgegeben. Um die Anonymität de#{c==1? 's':'r'} Teilnehmer#{c==1? 's':''} zu wahren, wurden die Ergebnisse ausgelassen."
  end
end

