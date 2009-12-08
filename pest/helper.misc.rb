# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
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
    def makePos
        self < 0 ? 0 : self
    end
end

class Float
    def makePos
        self.to_i.makePos 
    end
end

class Magick::Image
    def dpifix
        (self.rows / 3507.0).round
    end
end
