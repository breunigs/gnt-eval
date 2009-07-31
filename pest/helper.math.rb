# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: HELPER.MATH
#
# Adds some useful features to the math class that are used by some
# PEST components.


module Math
    def self.max(a, b)
        a > b ? a : b
    end

    def self.min(a, b)
        a < b ? a : b
    end
end
