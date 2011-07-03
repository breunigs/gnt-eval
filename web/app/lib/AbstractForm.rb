# -*- coding: utf-8 -*-
# = AbstractForm.rb - Everything you need to have an abstract form
#
# Contains the following classes:
# - AbstractForm: Basic class containing pages and dbtable
# - Page: Containing list of questions on that particular page
# - Question: see class.
# - Box: see class
#

require 'prettyprint'

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

  # FIXME: remove failchoice
  def initialize(boxes = [], qtext='', failchoice=-1,
                 nochoice=nil, type='square', db_column='', save_as = '')

    @boxes = boxes
    @qtext = qtext
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
    not @active.nil?
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

  # question itself in appropriate language and gender
  def text(language = :en, gender = :both)
    q = @qtext[language]
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
    case @type
      when "text_wholepage":
        # don't need to do anything for that
      when "text":
        s << "\n\n\\comment{#{text(lang, gender)}}{#{@db_column}}{#{@db_column}}\n\n"

      when "tutor_table":
        # automatically prints tutors, if they have been defined
        s << "\\printtutors{#{text(lang, gender)}}\n\n"

      when "variable_width":
        s << "\\SaveNormalInfo[#{text(lang, gender)}][#{@db_column}]\n"
        s << "\\printspecialheader{#{text(lang, gender)}}"

        s << "\\hspace*{-0.14cm}\\makebox[1.0\\textwidth][l]{"
        boxes = []
        @boxes.each do |b|
          boxes << "\\boxvariable{#{b.choice}}{\\hspace{-0.5em}#{b.text[lang]}}"
        end
        s << boxes.join(" \\hfill ")
        s << "}\n\n"

      when "fixed_width__last_is_rightmost":
        s << "\\SaveNormalInfo[#{text(lang, gender)}][#{@db_column}]\n"
        s << "\\printspecialheader{#{text(lang, gender)}}"

        s << "\\hspace*{-0.14cm}\\makebox[1.0\\textwidth][l]{"
        @boxes.each do |b|
          next if b == @boxes.last
          s << "\\boxfixed{#{b.choice}}{#{b.text[lang]}} "
        end

        (6-@boxes.size).times { s << "\\boxfixedempty" }
        last = @boxes.last
        s << "\\boxfixed{#{last.choice}}{#{last.text[lang]}} "
        s << "}\n\n"

      when "square":
        s << "\n\n"
        s << '\quest'
        s << '<m>' if multi?
        # db column
        if multi?
          s << '{' + @db_column.first[0..-2] + '}'
        else
          s << "{#{@db_column}}"
        end
        # question
        s << "{#{text(lang, gender)}}"
        # possible answers
        s << @boxes.sort{ |x,y| x.choice <=> y.choice }.map{ |x| "[#{x.text[lang]}]" }.join
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

  def special_care_questions
    questions.select { |q| q.special_care && q.special_care.to_i > 0 }
  end
end


# main form, list of pages and dbtable.
#

class AbstractForm
  # printed headline of the form
  attr_accessor :title

  # introductory text just below the main headline
  attr_accessor :intro

  # the language class that should be passed to TeX's babel
  attr_accessor :babelclass

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

  # builds the tex header for the form
  def header(language = :en, gender = :female, barcode = "0"*8)
    I18n.locale = language
    I18n.load_path += Dir.glob(File.join(Rails.root, 'config/locales/*.yml'))

    # writes yaml header on texing
    s = "\\head{#{title[language]}}{#{barcode}}\n\n"
    s << "#{intro[language]}\n\n"
    s << "\\\dataline{#{I18n.t(:title)}}"
    s << "{#{I18n.t(:lecturer)[gender]}}{#{I18n.t(:semester)}}\n\n"
    # print special questions
    special_care_questions.each { |q| s << q.to_tex(language, gender) }
    s << "\\vspace{0.1cm}"
    s
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

  # find the question-object belonging to a db_column
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
end

