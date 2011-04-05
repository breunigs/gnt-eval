# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: HELPER.BOXTOOLS
#
# Provides functions that wrap around the topic of "boxes" as used to
# define certain areas of the sheets where user input may be
#
# FIXME: Functions should be moved to class

require File.dirname(__FILE__) + '/helper.constants.rb'

# Finds out the box dimensions for the current group (doesn't look
# at individual box sizes)
def getGenericBoxDimension(group)
    case group.type
        when "square" then
            width, height = SQUARE_SEARCH
        else
            width = height = 0
    end
    return width*@dpifix, height*@dpifix
end

# Finds the size for a given box in the current question. If the box
# has no specific size, it will fall back to the generic size
def getBoxDimension(box, group)
    return box.width, box.height unless box.width.nil? || box.height.nil? || box.width == 0 || box.height == 0
    return getGenericBoxDimension(group)
end

# Splits a given box into boxes that are smaller or equal than the
# given maxWidth and maxHeight. Returns an array of boxes.
def splitBoxes(box, maxWidth, maxHeight)
    boxes = []

    # Due problems in TeX in regard of getting the width of certain
    # boxes, it's also possible to define a start box with top left
    # coordinates and height. A later box will contain the top right
    # coordinates and thus allows a complete box to be built.
    if box.width.nil? && box.type == "start"
        @temporaryBoxX=box.x
        @temporaryBoxY=box.y
        @temporaryBoxH=box.height
        return []
    end

    if box.width.nil? && box.type == "end"
        box.width = box.x - @temporaryBoxX
        box.height = @temporaryBoxH
        box.x = @temporaryBoxX
        box.y = @temporaryBoxY
    end

    # Split in width
    while box.width > maxWidth
        box.width -= maxWidth

        boxes << Box.new(nil, box.x + box.width, box.y, maxWidth, box.height, nil)
    end
    boxes << box

    allBoxes = []
    # Split in height
    boxes.each do |box|
        while box.height > maxHeight
            box.height -= maxHeight

            allBoxes << Box.new(nil, box.x, box.y + box.height, box.width, maxHeight, nil)
        end
        allBoxes << box
    end

    allBoxes
end

# Calculates the bounds for given set of boxes
def calculateBounds(boxes, group, borderLeft = 0)
    width, height = getGenericBoxDimension(group)

    xmin = 999999
    xmax = 0

    ymin = 999999
    ymax = 0

    boxes.each do |b|
        xmin = Math.min(xmin, b.x)
        ymin = Math.min(ymin, b.y)

        xmax = Math.max(xmax, b.x + (b.width  ? b.width  : 0))
        ymax = Math.max(ymax, b.y + (b.height ? b.height : 0))
    end

    # FIX component will use the borderLeft to make space for drawing
    # the "no choice" option"
    xmin -= (50 + borderLeft)
    ymin -= 50
    xmax += 50 + width
    ymax += 50 + height

    # Format: x, y, width, height
    return xmin, ymin, xmax-xmin, ymax-ymin
end
