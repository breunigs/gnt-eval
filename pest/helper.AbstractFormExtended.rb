# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: HELPER.AbstractFormExtended
#
# Add some handy attributes to AbstractForm.rb's classes

class Box
  # bp stands for "black percentage" and holds how much pixels in this
  # box are black. mx and my define the inner, top left corner of the
  # current box. These are only used for debugging purposes.
  attr_accessor :bp, :mx, :my

  # value to insert into database
  attr_accessor :choice

  # original coordinates
  attr_accessor :x,:y

  # size
  attr_accessor :width, :height

  # what is the _meaning_ of this box
  attr_accessor :text

  # special value for easier LaTeX sheet generation
  attr_accessor :type


  def initialize(c, x, y, w, h, t)
    @choice = c
    @x = x
    @y = y
    @width = w
    @height = h
    @text = t
    @type = ""
  end
end

class Question
  attr_accessor :value
end
