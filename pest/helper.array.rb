# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: HELPER.ARRAY
#
# Adds some useful features to the array class that are used by some
# PEST components.

class Array
    # Sums the array
    def sum;
        inject(nil) { |sum,x| sum ? sum+x : x }
    end

    # Calculates the mean of the array
    def mean
        inject(nil) { self.sum / self.length.to_f }
    end

    # Calculates the median of the array
    def median
        sorted = self.sort
        mid = self.length / 2
        (self.length % 2 == 1) ? sorted[mid] : ((sorted[mid] + sorted[mid - 1]) / 2)
    end

    # Splits up array into arrays of unequal size. The first array will
    # be the largest. Given you want 3 pieces, the first array will con-
    # tain 3/6, the second 2/6 and the third 1/6
    def sqrtChunk(pieces = 2)
        all = 0
        1.upto(pieces) { |x| all += x }
        eqlchnk = self.chunk(all)
        chunks = []
        start = 0
        pieces.downto(1) do |x|
            chunks << eqlchnk[start..(start + x - 1)].flatten
            start += x
        end
        chunks
    end

    # Selects previous element to the given one in self
    def previous(el)
        i = self.index(el)
        return nil if !i
        self[i - 1] 
    end

    # Selects next element to the given one in self
    def next(el)
        i = self.index(el)
        return nil if !i
        self[i + 1] 
    end

    # Joins all children of the current array into one and returns that
    #def allChildren
    #    a = []
    #    self.each { |x| x.each { |y| a << y } }
    #    a
    #end
end
