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
# - width, height: size
# - text: what is the _meaning_ of this box

class Box
  attr_accessor :choice, :x, :y, :width, :height, :text

  def initialize(c, x, y, w, h)
    @choice = c
    @x = x
    @y = y
    @width = w
    @height = h
  end
end

# - boxes: list of boxes
# - text: text of the question
# - failchoice: value to insert into database if OMR fails
# - nochoice: value to insert into db if there is no mark
# - type: what does the box look like (i.e. square)
# - dbfield: into which field to write the result
# - active: active question?
# - save_as: postfix when saving file (got an alias saveas)
class Question 
  attr_accessor :boxes, :qtext, :failchoice, :nochoice,
                :type, :dbfield, :active

  def initialize(boxes = [], qtext='', failchoice=-1,
                 nochoice=nil, type='square', dbfield='',
                 active=true, save_as = '')

    @boxes = boxes
    @qtext = qtext
    @failchoice = failchoice
    @nochoice = nochoice
    @type = type
    @dbfield = dbfield
    @active = active
    @save_as = save_as
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
