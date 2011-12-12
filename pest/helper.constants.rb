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
SQUARE_SEARCH = 55, 55

# FIXME: This file should contain the definitions where to recognize the
# rotation and offset

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

# Angle between diagonal and page top
PAGE_DIAG_ANGLE = Math.atan(PAGE_WIDTH/PAGE_HEIGHT)


# set the different fill grade levels. Checkboxes below or above the
# min/max fill grade will be marked as not checked. DESPERATE_ is only
# used if the question has not been answered and ISN'T a multi choice
# question. Values are in percent of black pixels to available space.
# Be aware that the OMR may do several passes and check many areas
# using MIN_FILL_GRADE before finally resorting to DESPERATE_MIN_FILL.
DESPERATE_MIN_FILL_GRADE = 2.7
MIN_FILL_GRADE = 5
MAX_FILL_GRADE = 80
