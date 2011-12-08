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
require 'RandomUtils.rb'

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

  # just get any description from the @text field. This should probably
  # be /the/ accessor for @text, similar to the way question#text works.
  def any_text(lang = :en)
    return @text if @text.is_a? String
    (return @text[lang.to_sym] || @text[:en] || @text.first[1]) if @text.is_a? Hash
    ""
  end
end

# This is a question on a printed form. Nothing more.
class Question
  # list of boxes
  attr_accessor :boxes

  # text of the question
  attr_accessor :qtext

  # what does the box look like (defaults to square)
  attr_accessor :type

  # into which field to write the result (use a list for multiple choice questions!)
  attr_accessor :db_column

  # postfix when saving file. Will always use the same as db_column.
  def save_as
    @db_column
  end
  # for compatibility reasons
  alias :saveas :save_as

  # height of the text field (only used iff type == comment)
  attr_accessor :height

  # boolean that tells if an additional <no answer> field has been added
  attr_accessor :no_answer

  # boolean that tells if the answers below each question should be hidden
  attr_accessor :hide_answers

  # FIXME: special care is depricated
  # special care: boolean, true falls extra liebe benoetigt wird
  # (tutoren, studienfach, semesterzahl)

  attr_accessor :special_care
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
    @height = nil
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

  # returns false iff no_answer has set been to false. Returns true if
  # no_answer was either not set or has been explicitly set to true.
  def no_answer?
    return true if @no_answer.nil?
    @no_answer
  end

  # returns false if hide_answers has set been to false or not been set
  # up at all. Returns true iff it has been explicitly set.
  def hide_answers?
    return false if @hide_answers.nil?
    @hide_answers
  end

  # is the question active?
  def active?
    not @active.nil?
  end

  # leftmost choice in appropriate language
  def ltext(language = :en)
    @boxes.first.any_text(language)
  end

  # rightmost choice in appropriate language
  def rtext(language = :en)
    @boxes.last.any_text(language)
  end

  # collect all possible choices and return as array
  def get_choices(language = :en)
    @boxes.collect { |x| x.any_text(language) }
  end

  # question itself in appropriate language and gender
  def text(language = :en, gender = :both)
    return @qtext if @qtext.is_a? String
    q = @qtext[language.to_sym] || @qtext.first[1] || ""
    return q if q.is_a? String
    q.is_a?(String) ? q : q[gender]
  end

  # did the user fail to answer the question?
  def failed?
    return @value == 0 || @value.to_i < 0
  end

  # didn't the user make any choice?
  def nochoice?
    return @value == 0
  end

  # is this a multi-answer question?
  def multi?
    return @db_column.is_a?(Array)
  end

  # export a single question to tex (used for creating the forms)
  def to_tex(lang = :en, gender = :both)
    s = ""
    qq = text(lang, gender)
    case @type
      when "text_wholepage" then
        # don't need to do anything for that
      when "text" then
        s << "\n\n\\comment#{height ? "<#{height}>" : ""}{#{qq}}{#{@db_column}}\n\n"

      when "tutor_table" then
        # automatically prints tutors, if they have been defined
        s << "\n\\printtutors{#{qq}}\n"

      when "variable_width" then
        s << "\\SaveNormalInfo[#{qq}][#{@db_column}]\n"
        s << "\\printspecialheader{#{qq}}"

        s << "\\hspace*{-0.14cm}\\makebox[1.0\\textwidth][l]{"
        boxes = []
        @boxes.each_with_index do |b,i|
          boxes << "\\boxvariable{#{i+1}}{\\hspace{-0.5em}#{b.text[lang]}}"
        end
        s << boxes.join(" \\hfill ")
        s << "}\n\n"

      # WARNING: Support for this type of question will be removed. Do not use.
      # TODO: Remove function once safe.
      when "fixed_width__last_is_rightmost" then
        s << "\\SaveNormalInfo[#{qq}][#{@db_column}]\n"
        s << "\\printspecialheader{#{qq}}"

        s << "\\hspace*{-0.14cm}\\makebox[1.0\\textwidth][l]{"
        @boxes.each_with_index do |b,i|
          next if b == @boxes.last
          s << "\\boxfixed{#{i+1}}{#{b.text[lang]}} "
        end

        (6-@boxes.size).times { s << "\\boxfixedempty" }
        last = @boxes.last
        s << "\\boxfixed{#{@boxes.count}}{#{last.text[lang]}} "
        s << "}\n\n"

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
        s << "\\quest"
        # single/multi and no_answer settings
        s << "<#{multi? ? "multi" : "single"} #{(no_answer? ? "noanswer" : "")} #{(hide_answers? ? "hideAnswers" : "")}>"
        # db column
        s << "{#{multi? ? @db_column.first[0..-2] : @db_column}}"
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

  include FunkyDBBits

  # used in the result pdfs
  # h: hash correspoding to specific (!) where clause
  # g: hash corresponding to general (!) where clause
  def eval_to_tex(h, g, db_table, lang = :en, gender = :both)
    @db_table = db_table

    b = ''
    if @db_column.is_a?(Array) # multi-q

      answers = multi_q(h, self, lang)
      b << TeXMultiQuestion.new(text(lang, gender), answers).to_tex

    else # single-q
      antw, anz, m, m_a, s, s_a = single_q(h, g, self)
      b << TeXSingleQuestion.new(text(lang, gender), ltext(lang),
             rtext(lang), antw, anz, m, m_a, s, s_a).to_tex if anz > 0
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
  def any_title(lang)
    return @title if @title.is_a? String
    return (@title[lang] || @title[:en] || @title.first[1] || "") if @title.is_a?(Hash)
    ""
  end

  attr_writer :answers
  def answers(lang)
    return @answers if @answers.is_a? Array
    return (@title[lang.to_sym] || @title[:en] || @title.first[1]) if @answers.is_a?(Hash)
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

  def special_care_questions
    questions.select { |q| q.special_care && q.special_care.to_i > 0 }
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

  # the language class that should be passed to TeX's babel
  attr_writer :babelclass
  def babelclass(lang)
    return (@babelclass || "") if @babelclass.nil? || @babelclass.is_a?(String)
    return @babelclass[lang.to_sym] || @babelclass[:en] || "english"
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

  def initialize(pages = [], db_table = '')
    @pages = pages
    @db_table = db_table
  end

  # direct access to questions
  def questions
    @pages.collect { |p| p.questions }.flatten
  end

  # returns all special care questions for that form
  def special_care_questions
    q = []
    @pages.each { |p| q += p.special_care_questions }
    q
  end

  # find the *first* question-object belonging to a db_column. There
  # shouldn’t be any duplicate db_columns per form, but it may happen…
  def get_question(db_column)
    questions.find { |q| q.db_column == db_column }
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
    questions.collect { |q| q.db_column }.get_duplicates.each do |d|
      h[d.to_sym] = questions.find_all { |q| q.db_column == d }.map { |q| q.text }
    end
    h
  end

  # returns true if there are any db columns used more than once
  def has_duplicate_db_columns?
    !questions.collect { |q| q.db_column }.get_duplicates.empty?
  end

  # returns the complete TeX code required to generate the form. If no
  # specific data is provided it will be filled with some default values
  def to_tex(
      lang = :en,
      title = "Jasper ist doof 3",
      lecturer ="Oliver ist doof",
      gender = :both,
      tutors = ["Mustafa Mustermann", "Fred Nurk", "Ashok Kumar",
                "Juan Pérez", "Jakob Mierscheid", "Iwan Iwanowitsch",
                "Pierre Dupont", "John Smith", "Eddi Exzellenz",
                "Joe Bloggs", "John Doe", "Stefan ist doof"],
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
    tex << "\\documentclass[#{babelclass(lang)}]{eval}\n"
    tex << "\\dozent{#{lecturer.escape_for_tex}}\n"
    tex << "\\vorlesung{#{title.escape_for_tex}}\n"
    tex << "\\dbtable{#{db_table}}\n"
    tex << "\\semester{#{semester.escape_for_tex}}\n"
    tex << "\\noAnswerText{#{I18n.t(:no_answer)}}\n"

    # tutors
    tutors.collect! { |t| t.escape_for_tex }
    tex << "\\tutoren{\n  "
    (0..28).each do |i|
      tex << "\\tutorbox[#{i+1}][#{tutors[i] || "\\\\ "}]".ljust(35)
      tex << ((i%5 == 4) ? '\\\\'+"\n  " : ' & ')
    end
    tex << "\\tutorbox[30][\\ #{I18n.t(:none)}] \n"
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
    # print special questions
    special_care_questions.each { |q| s << q.to_tex(lang, gender) }
    s << "\\vspace{-2.5mm}"
    s
  end

  def tex_questions(lang, gender)
    b = ""
    pages.each_with_index do |p,i|
      b << p.tex_at_top.to_s
      p.sections.each do |s|
        # skip special care questions. These are legacy ones and ought
        # to be removed. Until this, let’s keep this magic. TODO
        next if s.questions.find_all{|q| q.special_care != 1}.empty?
        b << ""
        b << "\\preventBreak{\n\\sect{#{s.any_title(lang)}}"
        b << s.answers(lang).map { |x| "[#{x}]" }.join unless s.answers(lang).nil?
        b << "\n"
        sect_open = true
        s.questions.each do |q|
          next if (q.special_care == 1 || (not q.donotuse.nil?)) && (not q.db_column =~ /comment/)
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
