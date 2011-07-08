# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: HELPER.AbstractFormExtended
#
# Add some handy attributes to AbstractForm.rb's classes

class Box
  # bp stands for "black percentage" and holds how much pixels in this
  # box are black. mx and my define the inner, top left corner of the
  # current box. These are only used for debugging purposes.
  attr_accessor :bp

  # stores the amount of black pixels in the searched area
  attr_accessor :black

  # set to true by omr2.rb if it believes this box is checked. This is
  # later picked up by fix.rb and draws a special border around this box
  attr_accessor :is_checked

  # set to true, when this box was selected with a low threshold or has
  # been deselected due to a too high fill dregree
  attr_accessor :fill_critical

  # original coordinates
  attr_accessor :x,:y

  # size
  attr_accessor :width, :height

  # what is the _meaning_ of this box
  attr_accessor :text

  def is_checked?
    !is_checked.nil? && is_checked
  end

  def is_fill_critical?
    !fill_critical.nil? && fill_critical
  end


  def choice
    @choice.to_i
  end

  def initialize(c, x, y, w, h, t)
    @choice = c
    @x = x
    @y = y
    @width = w
    @height = h
    @text = t
    @type = ""
  end

  def top_left
    [@x, @y]
  end
  alias :tl :top_left

  def bottom_right
    [@x+@width, @y+@height]
  end
  alias :br :bottom_right
end

class Question
  attr_accessor :value
end
