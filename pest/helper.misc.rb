# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: HELPER.MISC
#
# Adds some useful features to some classes that are used by some
# PEST components.


module Math
  def self.max(a, b)
    a > b ? a : b
  end

  def self.min(a, b)
    a < b ? a : b
  end
end

class Integer
  # legacy
  def makePos
    puts "makePos is deprecated"
    self < 0 ? 0 : self
  end

  def make_min_0
    self < 0 ? 0 : self
  end
end

class Magick::Image
  def dpifix
    (self.rows / 3508.0).round
  end
end

# prints the given debug text with a timestamp to the console. If
# timer, a string identifier, is given it will note the current time
# when called first and will print the duration after the 2nd call.
def debug text, timer = nil
  @debug ||= {}
  s = Time.now.strftime("[%T] ")
  s << text unless text.nil?
  # reset the timer after it has been printed once
  if timer && @debug[timer]
    text = ""
    s << " (took: #{Time.now-@debug[timer]}s)"
    @debug[timer] = nil
  elsif timer
    @debug[timer] = Time.now
  end
  puts s unless text.nil?
end
