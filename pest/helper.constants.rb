# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: HELPER.CONSTANTS
#
# Defines some random constants that may be used more than once

# Used to convert radians to degrees
RAD2DEG  = 360.0/(2.0 * Math::PI)
DEG2RAD  = (2.0 * Math::PI)/360.0

# _SEARCH defines the area in where to look for the printed element
# _SIZE   defines the width of the element with strokes/border
# _STROKE defines the stroke width
SQUARE_SEARCH = 55, 55
SQUARE_SIZE   = 40 # It's a square
SQUARE_STROKE = 4

# FIXME: This file should contain the definitions where to recognize the
# rotation and offset

# Scalepoints (sp) is the unit used by TeX to describe where elements are
# placed. However, the scanned images is processed by pixel values, so we
# need to calculate (TeX-Value)/SP_TO_PX to get the according value in px.
SP_TO_PX = 15800
