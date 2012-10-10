# encoding: utf-8

# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: HELPER.AbstractFormExtended
#
# Add some handy attributes to AbstractForm.rb's classes

cdir = File.dirname(__FILE__)
require cdir + '/helper.constants.rb'

class Box
  # bp stands for "black percentage" and holds how much pixels in this
  # box are black. mx and my define the inner, top left corner of the
  # current box. These are only used for debugging purposes.
  attr_accessor :bp

  # stores the amount of black pixels in the searched area
  attr_accessor :black

  # used to store if the box was empty, barely checked, checked or
  # overfull for the reference sheets. Since those are evaluated by
  # hand, there’s no black percentage available.
  attr_writer :omr_result

  # returns the omr_result variable if sheet was evaluated by hand (i.e.
  # omr_result variable is not nil). If it was evaluated by the computer
  # returns the corresponding results but derives its information from
  # the stored black percentage.
  def omr_result
    return @omr_result unless @omr_result.nil?
    return BOX_EMPTY if is_empty?
    return BOX_BARELY if is_barely_checked?
    return BOX_CHECKED if is_checked?
    return BOX_OVERFULL if is_overfull?
    nil # should only occur if @omr_result and black percentage are nil
  end

  # original coordinates
  attr_accessor :x,:y

  # size
  attr_accessor :width, :height

  def is_empty?
    !bp.nil? && bp < DESPERATE_MIN_FILL_GRADE
  end

  def is_barely_checked?
    !bp.nil? && bp >= DESPERATE_MIN_FILL_GRADE && bp < MIN_FILL_GRADE
  end

  def is_checked?
    !bp.nil? && bp >= MIN_FILL_GRADE && bp <= MAX_FILL_GRADE
  end

  def is_overfull?
    !bp.nil? && bp > MAX_FILL_GRADE
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

  def top_right
    [@x+@width, @y]
  end
  alias :tr :top_right

  def bottom_right
    [@x+@width, @y+@height]
  end
  alias :br :bottom_right

  def bottom_left
    [@x, @y+@height]
  end
  alias :bl :bottom_left
end

class Question
  attr_accessor :value
end

class Page
  attr_accessor :questions
end
