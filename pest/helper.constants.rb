# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: HELPER.CONSTANTS
#
# Defines some random constants that may be used more than once

# _SEARCH defines the area in where to look for the printed element
SQUARE_SEARCH = 55, 55

# Scalepoints (sp) is the unit used by TeX to describe where elements are
# placed. However, the scanned images is processed by pixel values, so we
# need to calculate (TeX-Value)/SP_TO_PX to get the according value in px.
# 72.27pt = 1 in
# 65536sp = 1 pt
# per default, 300 DPI scans are assumed. Therefore:
SP_TO_PX = 65536 * 72.27 / 300



# The dimension of the page when being scanned with 300 DPI in pixels.
# The default values are for A4 paper. Specify them as floats.
PAGE_HEIGHT = 3508.0
PAGE_WIDTH = 2480.0

# set the different fill grade levels. Checkboxes below or above the
# min/max fill grade will be marked as not checked. DESPERATE_ is only
# used if the question has not been answered and ISN'T a multi choice
# question. Values are in percent of black pixels to available space.
# Be aware that the OMR may do several passes and check many areas
# using MIN_FILL_GRADE before finally resorting to DESPERATE_MIN_FILL.
DESPERATE_MIN_FILL_GRADE = 2.7
MIN_FILL_GRADE = 5
MAX_FILL_GRADE = 80

# Defines how many black pixels a textbox should have before being
# considered to be filled. Assume the document has been scanned at 300
# DPI.
TEXTBOX_MIN_PIXELS = 1000

# used to unify what the special codes mean. The normal values for boxes
# start from 1 and count up. 99 may be used to identify special “user
# did not want to answer question” boxes. However, these are handled the
# same way the other boxes are in the OMR component.
ANSW_FAIL = -1
ANSW_NONE = 0

# Used to convert radians to degrees
RAD2DEG  = 360.0/(2.0 * Math::PI)
DEG2RAD  = (2.0 * Math::PI)/360.0

# Angle between diagonal and page top
PAGE_DIAG_ANGLE = Math.atan(PAGE_WIDTH/PAGE_HEIGHT)

# These are used in the testing area to make it the code more human
# readable and to unify the values. Only used for human input, the
# normal OMR component works on black percentage and the fill grades
# defined above.
BOX_EMPTY = 0
BOX_BARELY = 3
BOX_CHECKED = 1
BOX_OVERFULL = 2
