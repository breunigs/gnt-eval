# = Form.rb - Everything you need to have an abstract form
#
# Contains the following classes:
# - Form: Basic class containing pages and dbtable
# - Page: Containing list of questions on that particular page
# - Question: see class
# - Box: see class
#
# We won't do no eval stuff in here, this is _just_ the abstract
# notion of a form!



class Box
  
  # value to insert into database
  attr_accessor :coiche

  # coordinates
  attr_accessor :x,:y
  
  # size
  attr_accessor :width, :height

  # what is the _meaning_ of this box
  attr_accessor :text

  def initialize(c, x, y, w, h, t)
    @choice = c
    @x = x
    @y = y
    @width = w
    @height = h
    @text = t
  end
end


class Question 
  include FunkyDBBits

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
  
  # active question? (defaults to true)
  attr_accessor :active
  
  # postfix when saving file
  attr_accessor :save_as
  
  # belongs to: 'tutor', 'prof', 'tutoring'
  attr_accessor :section
  
  def initialize(boxes = [], qtext='', failchoice=-1,
                 nochoice=nil, type='square', db_column='',
                 active=true, save_as = '', section = '')

    @boxes = boxes
    @qtext = qtext
    @failchoice = failchoice
    @nochoice = nochoice
    @type = type
    @db_column = db_column
    @active = active
    @save_as = save_as
    @section = ''
  end

  # how many choices are there?
  def size
    return @boxes.count
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
  
  # question itself
  def text
    @qtext
  end
  
  def eval_to_tex(this_eval, bc, db_table, dbh)
    @dbh = dbh
    @db_table = db_table
    
    b = ''
    
    if @db_column.is_a?(Array)
        
      answers = multi_q({ 'eval' => this_eval, 'barcode' =>
                          bc}, self)
      
      t = TeXMultiQuestion.new(@qtext, answers)
      b << t.to_tex
      
      # single-q
    else
      antw, anz, m, m_a, s, s_a = single_q({'eval' => this_eval,
                                             'barcode' =>
                                             bc},
                                           {'eval' => this_eval}, self) 
      
      t = TeXSingleQuestion.new(text, ltext, rtext, antw,
                                anz, m, m_a, s, s_a)
      
      b << t.to_tex
    end
    return b
  end
end


# this is actually just needed for the OMR to distinguish between
# pages 
#

class Page

  # list of questions on that page
  attr_accessor :questions

  def initialize(qs = [])
    @questions = qs
  end
end


# main form, list of pages and (ATM) dbtable.
#

class Form
  
  # list of pages
  attr_accessor :pages
  
  # database table to use for this form
  attr_accessor :db_table

  def initialize(pages = [], db_table = '')
    @pages = pages
    @db_table = db_table
  end

  # direct access to questions
  def questions
    @pages.collect { |p| p.questions }.flatten
  end
end
