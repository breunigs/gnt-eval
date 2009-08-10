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


# - choice: value to insert into database
# - x,y: coordinates

class Box
  attr_accessor :choice, :x, :y

  def initialize(c, x, y)
    @choice = c
    @x = x
    @y = y
  end
end

# - boxes: list of boxes
# - text: text of the question
# - failchoice: value to insert into database if OMR fails
# - nochoice: value to insert into db if there is no mark
# - type: what does the box look like (i.e. square)
# - dbfield: into which field to write the result
# - active: active question?

class Question 
  attr_accessor :boxes, :qtext, :ltext, :rtext,
                :failchoice, :nochoice, :type, :dbfield, :active

  def initialize(boxes = [], qtext='', ltext='', rtext= '',
                 failchoice=-1, nochoice=nil, type='square',
                 dbfield='', active=true)
    @boxes = boxes
    @qtext = qtext
    @ltext = ltext
    @rtext = rtext
    @failchoice = failchoice
    @nochoice = nochoice
    @type = type
    @dbfield = dbfield
    @active = active
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
end


# this is actually just needed for the OMR to distinguish between
# pages 
#
# - questions: list of questions on that page

class Page
  attr_accessor :questions

  def initialize(qs = [])
    @questions = qs
  end
end


# main form, list of pages and (ATM) dbtable.
#
# == TODO
# - do we want other backends?
#   - No. It is a trivial task to get forms into a database.

class Form
  attr_accessor :pages, :dbtable

  def initialize(pages = [], dbtable = '')
    @pages = pages
    @dbtable = dbtable
  end

  # direct access to questions
  def questions
    @pages.collect { |p| p.questions }
  end
end
