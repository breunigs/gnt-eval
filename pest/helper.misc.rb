# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: HELPER.MISC
#
# Adds some useful features to some classes that are used by some
# PEST components.

cdir = File.dirname(__FILE__)
require cdir + '/helper.constants.rb'

class Array
  def x; self[0]; end
  def y; self[1]; end
  def x=(x); self[0]=x; end
  def y=(y); self[1]=y; end

  # Sums the array
  def sum
      inject(nil) { |sum,x| sum ? sum+x : x }
  end
end

module Enumerable
  def any_nil?
    self.any? {|x| x.is_a?(Enumerable) ? x.any_nil? : x.nil? }
  end
end

module Math
  def self.max(a, b)
    a > b ? a : b
  end

  def self.min(a, b)
    a < b ? a : b
  end
end

class Numeric
  # legacy
  def makePos
    puts "makePos is deprecated"
    self < 0 ? 0 : self
  end

  def make_min_0
    self < 0 ? 0 : self
  end

  def limit(min, max)
    raise "min and max switched" if min > max
    return min if self < min
    return max if self > max
    self
  end
end

class Float
  def round_to(x = 1)
    (self * 10**x).round.to_f / 10**x
  end

  def as_time
    if self > 60
      (self/60).round_to(1).to_s + " h"
    elsif self > 1
      self.round_to(1).to_s + " m"
    else
      (self*60).round.to_s + " s"
    end
  end
end

class Magick::Image
  def dpifix
    (self.rows / PAGE_HEIGHT.to_f).round
  end
end

# prints the given debug text with a timestamp to the console. If
# timer, a string identifier, is given it will note the current time
# when called first and will print the duration after the 2nd call.
def debug text = "", timer = nil
  @debug_timers ||= {}
  s = Time.now.strftime("[%T] ")
  s << text unless text.nil?
  # reset the timer after it has been printed once
  if timer && @debug_timers[timer]
    text = ""
    s << " (took: #{Time.now-@debug_timers[timer]}s)"
    @debug_timers[timer] = nil
  elsif timer
    @debug_timers[timer] = Time.now
  end
  puts s unless text.nil?
end
