# -*- coding: utf-8 -*-
# = AbstractForm.rb - Everything you need to have an abstract form
#
# Contains the following classes:
# - AbstractForm: Basic class containing pages and dbtable
# - Page: Containing list of questions on that particular page
# - Question: see class.
# - Box: see class
#
# The boxes are coded as follows:
# first box = 1, second box = 2, …, no answer box = 99
# When processing the sheets, the additional values are:
#  0 = no choice, i.e. the user did no cross anything
# -1 = multiple checkmarks were detected, not yet confirmed by human
# -2 = multiple checkmarks are there, confirmed by human

# TODO: Remove "choice" from box if safe. First needs to be removed from
# Pest and eval.cls


require 'prettyprint'
cdir = File.dirname(__FILE__)
require cdir + '/RandomUtils.rb'

# Defines how many checkboxes are available for tutors. The last one is
# used for 'none'. The boxes are laid out five per row, so the number
# should be divisible by five.
TUTOR_BOX_COUNT = 30 unless defined?(TUTOR_BOX_COUNT)

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

  # if this is a comment field, we need to know its height
  attr_accessor :height

  def initialize(c, t)
    @choice = c
    @text = t
  end

  # just get any description from the @text field. This should probably
  # be /the/ accessor for @text, similar to the way question#text works.
  def any_text(lang = I18n.locale)
    return @text if @text.is_a? String
    (return @text[lang.to_sym] || @text[:en] || @text.first[1]) if @text.is_a? Hash
    ""
  end
end

# This is a question on a printed form. Nothing more.
class Question
  # list of boxes. Does NOT include the «no answer» checkbox, even when
  # enabled.
  attr_accessor :boxes

  # text of the question
  attr_accessor :qtext

  # what does the box look like (defaults to square)
  attr_accessor :type

  # into which field to write the result (use a list for multiple choice questions!)
  attr_accessor :db_column

  # postfix when saving file. Will always use the same as db_column.
  def save_as
    # the join is required in case we hit a multiple choice question.
    # It’s highly unlikely that this kind of question will ever use the
    # save_as attribute, but what the heck.
    # Also, keep only valid chars
    [@db_column].join.gsub(/[^a-z0-9-]/i, "")
  end

  # height of the text field (only used iff type == comment)
  attr_accessor :height

  # boolean that tells if an additional <no answer> field has been added
  attr_accessor :no_answer

  # boolean that tells if the answers below each question should be hidden
  attr_accessor :hide_answers

  # Floating point or integer value that specifies if the last checkbox
  # should be made a textbox instead. You can use this if you want
  # common values to be checkable but still allow any value. <nil> or 0
  # means “off”, i.e. last box is a normal checkbox and any value larger
  # than 0 means it’s on. Good ones are between 15 and 30 (millimeter).
  # Will create an additional DB column which appends _text to the name
  # given in db_column. Manual retrieval is usually not required.
  attr_accessor :last_is_textbox

  # Specify the type of visualizer you want to use to represent this
  # question in the result PDF. You can specify more than one
  # visualization by making this an array. For possible values have a
  # look at tex/results/multi_*.tex.erb for multiple choice questions
  # and at tex/results/single_*.tex.erb for single choice questions. The
  # globbing star indicates the name to specify.
  # By default the _empty visualizer will be used which only prints a
  # comment into the TeX file.
  attr_writer :visualizer
  def visualizer
    warn "WARNING: No visualizer set for #{text}" if @visualizer.nil?
    @visualizer || "empty"
  end

  # returns if the visualizer has been set or false, if the variable is
  # not defined.
  def visualizer_set?
    !@visualizer.nil?
  end

  attr_accessor :donotuse

  # FIXME: remove failchoice and nochoice
  def initialize(boxes = [], qtext='', failchoice=-1,
                 nochoice=nil, type='square', db_column='')

    @boxes = boxes
    @qtext = qtext
    @type = type
    @db_column = db_column
    @no_answer = true
    @hide_answers = false
    @last_is_textbox = nil
    @height = nil
  end

  # how many choices are there?
  def size
    return TUTOR_BOX_COUNT if type == "tutor_table"
    @boxes.nil? ? 0 : @boxes.count
  end

  # Returns for which entities this question should be repeated or where
  # it belongs to. Returns either of the following:
  # :course, :lecturer, :tutor
  # Where :course says this question should only be shown once (default).
  # :lecturer and :tutor indicate this question should be evaluated
  # separately for each lecturer/tutor.
  def repeat_for
    # if loaded via YAML 2 Ruby this variable will be a string or nil,
    # thus the .to_sym is required.
    (@repeat_for || :course).to_sym
  end

  # Set value for which entities this question should be repeated. If
  # you specify something other than :course, :lecturer or :tutor it
  # will fall back to :course and print a warning.
  def repeat_for=(val)
    val = val.to_sym
    valid = [:course, :lecturer, :tutor]
    if valid.contains?(val)
      @repeat_for = val
    else
      warn "Invalid repeat_for value has been set."
      warn "Given: #{val}"
      warn "Allowed: #{valid.join(", ")}"
      @repeat_for = nil
    end
  end

  # returns false iff no_answer has set been to false. Returns true if
  # no_answer was either not set or has been explicitly set to true.
  def no_answer?
    return true if @no_answer.nil?
    @no_answer
  end

  def last_is_textbox?
    !@last_is_textbox.nil? && @last_is_textbox > 0
  end

  # returns false if hide_answers has set been to false or not been set
  # up at all. Returns true iff it has been explicitly set.
  def hide_answers?
    return false if @hide_answers.nil?
    @hide_answers
  end

  # leftmost choice in appropriate language
  def ltext(language = I18n.locale)
    @boxes.first.any_text(language)
  end
  alias :leftmost_pole :ltext

  # rightmost choice in appropriate language. Does NOT include «no
  # answer», use no_answer? and check it yourself.
  def rtext(language = I18n.locale)
    @boxes.last.any_text(language)
  end
  alias :rightmost_pole :rtext

  # finds the answer text for each checkbox and returns them as an array
  # in-order. Does NOT include «no answer», use no_answer? and check it
  # yourself. Returns an empty array if no boxes have been defined.
  # Does NOT include the additional answers if last_is_textbox is set to
  # true.
  def get_answers(language = I18n.locale)
    return [] if boxes.nil? || boxes.empty?
    boxes.collect { |x| x.any_text(language) }
  end

  # question itself in appropriate language and gender
  def text(language = I18n.locale, gender = :both)
    return @qtext if @qtext.is_a? String
    q = @qtext[language.to_sym] || @qtext.first[1] || ""
    return q if q.is_a? String
    q.is_a?(String) ? q : q[gender.to_sym]
  end

  # did the user fail to answer the question? (either too many check-
  # marks or none)
  def failed?
    @value == 0 || @value.to_i < 0
  end

  # didn't the user make any choice? (i.e. no checkmarks at all)
  def nochoice?
    multi? ? (@value.empty?) : (@value == 0)
  end

  # is this a multi-answer question?
  def multi?
    @db_column.is_a?(Array) && !comment?
  end

  # is this a single-answer question? Note that comment fields are also
  # handled that way, since they
  def single?
    !multi?
  end

  # true if this question contains hand-written data (or images) rather
  # than statistical data
  def comment?
    ["text", "text_wholepage"].include?(@type)
  end

  # export a single question to tex (used for creating the forms)
  def to_tex(lang = I18n.locale, gender = :both)
    s = ""
    qq = text(lang, gender) # FIXME, lecturer’s name is currently broken
    case @type
      when "text_wholepage" then
        # don't need to do anything for that
      when "text" then
        s << "\n\n\\comment#{height ? "<#{height}>" : ""}{#{qq}}{#{@db_column}}\n\n"

      when "tutor_table" then
        # automatically prints tutors, if they have been defined
        s << "\n\\printtutors{#{qq}}{#{@db_column}}\n"

      when "square" then
        answers = @boxes.map{ |x| "[#{x.any_text(lang)}]" }
        # add dummy entry so the no answer checkbox in the first row is taken
        # into account. it will be removed later.
        answers.unshift(nil) if no_answer?
        # split checkboxes into equal parts so there are the same amount of
        # answers per row. If there are six or less answers, only one row is
        # required.
        answers = answers.chunk([1, (@boxes.count/6.0).ceil].max)
        first = answers.shift
        # print additional answers
        answers.each { |x| s << "\\moreAnswers#{x.join}\n" }
        s << "\\setlength{\\lastBoxSize}{#{last_is_textbox}mm}\n" if last_is_textbox?
        s << "\\quest"
        # single/multi and no_answer settings
        opt = []
        opt << (multi? ? "multi" : "single")
        opt << (no_answer? ? "noanswer" : nil)
        opt << (hide_answers? ? "hideAnswers" : nil)
        opt << (last_is_textbox? ? "lastIsTextbox" : nil)
        s << "<#{opt.compact.join(" ")}>"
        # db column
        s << "{#{multi? ? @db_column.find_common_start : @db_column}}"
        # question
        s << "{#{qq}}"
        # first row of answers (compact removes dummy element, if required)
        s << first.compact.join
        s << "\n\n"
    end
    s
  end

  def tex_db_column
    if multi?
      c = @db_column.first
      c[0,c.length-1]
    else
      @db_column
    end
  end
end


# groups questions of the same type or of the same category together
# and prints a header into the questionnaire and into the results
class Section
  attr_accessor :title

  attr_writer :questions
  def questions
    @questions || []
  end

  def initialize(t ='', q=[])
    @title = t
    @questions = q
  end

  # tries to get the text in the following order:
  # 1. given language, 2. in English, 3. whatever comes first
  def any_title(lang = I18n.locale)
    return @title if @title.is_a? String
    return (@title[lang] || @title[:en] || @title.first[1] || "") if @title.is_a?(Hash)
    ""
  end

  attr_writer :answers
  def answers(lang = I18n.locale)
    return @answers if @answers.is_a? Array
    return (@answers[lang.to_sym] || @answers[:en] || @answers.first[1]) if @answers.is_a?(Hash)
    []
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
  # printed headline of the form
  attr_writer :title
  def title(lang)
    return (@title || "") if @title.nil? || @title.is_a?(String)
    return @title[lang.to_sym] || @title[:en] || ""
  end

  # introductory text just below the main headline
  attr_writer :intro
  def intro(lang)
    default = I18n.t(:default_intro)
    return (@intro || default) if @intro.nil? || @intro.is_a?(String)
    return @intro[lang.to_sym] || @intro[:en] || default
  end

  # list of pages
  attr_accessor :pages

  # database table to use for this form
  attr_accessor :db_table

  # we differentiate gender here
  attr_accessor :lecturer_header

  # return an empty string instead of nil for texhead and texfoot
  attr_writer :texhead, :texfoot
  def texhead
    @texhead || ""
  end
  def texfoot
    @texfoot || ""
  end

  # returns how many pages will be used in the resulting PDF. Warning:
  # result is not cached, so this method is very slow.
  def actual_page_count
    warn "WARNING: actual_page_count is not yet implemented properly."
    warn "         Please send patches."
    @pages.count
  end

  def initialize(pages = [], db_table = '')
    @pages = pages
    @db_table = db_table
  end

  # direct access to sections
  def sections
    @pages.collect { |p| p.sections }.flatten
  end

  # direct access to questions
  def questions
    @pages.collect { |p| p.questions }.flatten
  end

  # find the *first* question-object belonging to a db_column. There
  # shouldn’t be any duplicate db_columns per form, but it may happen…
  def get_question(db_column)
    questions.find { |q| q.db_column == db_column }
  end

  # checks if this form contains a question of a certain type.
  def include_question_type?(type)
    questions.any? { |q| q.type == type }
  end

  # returns the question with type == tutor_table if available. If the
  # form does not support tutors, nil is returned.
  def get_tutor_question
    questions.find { |q| q.type == "tutor_table" }
  end

  # pretty printing an AbstrctForm is a bit gnaahaha
  # this does NOT stout but returns a string
  # GOTCHA: never name this pretty_print.
  def pretty_print_me
    sio = PP.pp(self, "")

    # aber bitte ohne die ids und ohne @
    sio.gsub(/0x[^\s]*/,'').gsub(/@/,'')
  end


  # returns list of db dolumn names that are used more than once and the
  # offending questions. returns empty hash if there aren’t any
  # duplicates and something like this, if there are:
  # { :offending_column => ["Question 1?", "Question 2?"] }
  def get_duplicate_db_columns
    h = {}
    c = get_all_db_columns
    c.get_duplicates.each do |d|
      h[d.to_sym] = c.find_all { |q| q.db_column == d }.map { |q| q.text }
    end
    h
  end

  # returns true if there are any db columns used more than once
  def has_duplicate_db_columns?
    !get_all_db_columns.get_duplicates.empty?
  end

  # returns true if there is a question without explicitly set visualizer
  def has_questions_without_visualizer?
    questions.any? { |q| !q.visualizer_set? }
  end

  # returns the questions which do not have an visualizer explicitly set
  def get_questions_without_visualizer
    questions.reject { |q| q.visualizer_set? }
  end


  # returns the complete TeX code required to generate the form. If no
  # specific data is provided it will be filled with some default values
  def to_tex(
      lang = I18n.locale,
      title = "Jasper ist doof 3",
      lecturer_first = "Oliver",
      lecturer_last = "Istdoof",
      gender = :both,
      tutors = ["Mustafa Mustermann", "Fred Nurk", "Ashok Kumar",
                "Juan Pérez", "Jakob Mierscheid", "Iwan Iwanowitsch",
                "Pierre Dupont", "John Smith", "Eddi Exzellenz",
                "Joe Bloggs", "John Doe", "Stefan ist doof",
                "Beccy ist doof"],
      semester = "the same semester as last year",
      barcode = "00000000")

    # in case someone didn’t give us symbols
    lang, gender = lang.to_sym, gender.to_sym

    # set lang and load locales for default strings that are not part of
    # the form
    I18n.locale = lang
    I18n.load_path += Dir.glob(File.join(Rails.root, 'config/locales/*.yml'))
    I18n.load_path.uniq!

    tex = ""

    # form header and preamble
    tex << "\\documentclass[#{I18n.t(:tex_babel_lang)}]{eval}\n"
    tex << "\\lecturerFirst{#{lecturer_first.escape_for_tex}}\n"
    tex << "\\lecturerLast{#{lecturer_last.escape_for_tex}}\n"
    tex << "\\lecture{#{title.escape_for_tex}}\n"
    tex << "\\dbtable{#{db_table}}\n"
    tex << "\\term{#{semester.escape_for_tex}}\n"
    tex << "\\noAnswerText{#{I18n.t(:no_answer)}}\n"
    # note: these cannot be customized per tutor, as the tutor is not
    # known yet. They will be filled in result.pdf, so give placeholders
    # instead.
    tex << "\\setTutor{#{I18n.t(:tutor)}}\n"
    tex << "\\setMyTutor{#{I18n.t(:my_tutor)}}\n"

    # tutors
    tutors.collect! { |t| t.escape_for_tex }
    tex << "\\tutors{\n  "
    (0..(TUTOR_BOX_COUNT-2)).each do |i|
      tex << "\\tutorbox[#{i+1}][#{tutors[i] || "\\\\ "}]".ljust(35)
      tex << ((i%5 == 4) ? '\\\\'+"\n  " : ' & ')
    end
    tex << "\\tutorbox[#{TUTOR_BOX_COUNT}][\\ #{I18n.t(:none)}] \n"
    tex << "}\n\n"

    tex << get_texhead(lang) + "\n"
    tex << "\\begin{document}\n"
    tex << tex_header(lang, gender, barcode) + "\n\n\n"
    tex << tex_questions(lang, gender) + "\n"
    tex << get_texfoot(lang) + "\n"
    tex << "\\end{document}"

    tex
  end

  # small helper functions follow that are only used internally
  private
  # returns array of db columns used in this form
  def get_all_db_columns
    quest = questions.collect { |q| q.db_column }
    litf = questions.reject { |q| !q.last_is_textbox? } .map { |q| \
              (q.multi? ? q.db_column.last : q.db_column) + "_text" }
    (quest+litf)
  end

  def get_texhead(lang)
    (texhead.is_a?(String) ? texhead : texhead[lang.to_sym]) || ""
  end

  def get_texfoot(lang)
    (texfoot.is_a?(String) ? texfoot : texfoot[lang.to_sym]) || ""
  end

  # builds the tex header for the form
  def tex_header(lang, gender, barcode)
    # writes yaml header on texing
    s = "\\head{#{title(lang)}}{#{barcode}}\n\n"
    s << "#{intro(lang)}\n\n"
    s << "\\vspace{0.8mm}"
    s << "\\dataline{#{I18n.t(:title)}}"
    s << "{#{I18n.t(:lecturer)[gender]}}{#{I18n.t(:semester)}}\n"
    s << "\\vspace{-2.5mm}"
    s
  end

  def tex_questions(lang, gender)
    b = ""
    pages.each_with_index do |p,i|
      b << p.tex_at_top.to_s
      p.sections.each do |s|
        b << ""
        b << "\\preventBreak{\n\\sect{#{s.any_title(lang)}}"
        b << s.answers(lang).map { |x| "[#{x}]" }.join unless s.answers(lang).nil?
        b << "\n"
        sect_open = true
        s.questions.each do |q|
          next if ((not q.donotuse.nil?)) && (not q.db_column =~ /comment/)
          quest = q.to_tex(lang, gender)
          # need to remove line breaks at the end to avoid spacing issues
          b << (sect_open ? quest.strip : quest)
          b << "\n}\n\n" if sect_open
          sect_open = false
        end
      end
      b << p.tex_at_bottom.to_s
    end
    b
  end
end
