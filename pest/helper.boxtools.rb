# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: HELPER.BOXTOOLS
#
# Provides functions that wrap around the topic of "boxes" as used to
# define certain areas of the sheets where user input may be
#
# FIXME: Functions should be moved to class

require 'helper.constants.rb'

# Finds out the box dimensions for the current group (doesn't look
# at individual box sizes)
def getGenericBoxDimension(group)
    case group["type"]
        when "square" then
            width, height = SQUARE_SEARCH
        when "text" then
            # Text may or may not have more than one box. If so,
            # the width and height are not stored on the group.
            # In any case, take whatever you can get.
            width  = group['width']  ? group['width']  : 0
            height = group['height'] ? group['height'] : 0
        else
            width = height = 0
    end
    return width, height
end

# Finds the size for a given box in the current group. If the box
# has no specific size, it will fall back to the generic size
def getBoxDimension(box, group)
    return box['width'], box['height'] if box['width'] && box['height']
    return getGenericBoxDimension(group)
end

# Splits a given box into boxes that are smaller or equal than the
# given maxWidth and maxHeight. Returns an array of boxes.
def splitBoxes(box, maxWidth, maxHeight)
    boxes = []
    # Split in width
    while box['width'] > maxWidth
        box['width'] -= maxWidth

        boxes << { "x" => box['x']+box['width'], "y" => box['y'],
                   "width" => maxWidth, "height" => box['height'] }
    end
    boxes << box

    allBoxes = []
    # Split in height
    boxes.each do |box|
        while box['height'] > maxHeight
            box['height'] -= maxHeight

            allBoxes << { "x" => box['x'], "y" => box['y']+box['height'],
                          "width" => box['width'], "height" => maxHeight }
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
        xmin = Math.min(xmin, b['x'])
        ymin = Math.min(ymin, b['y'])

        xmax = Math.max(xmax, b['x'] + (b['width']  ? b['width']  : 0))
        ymax = Math.max(ymax, b['y'] + (b['height'] ? b['height'] : 0))
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
