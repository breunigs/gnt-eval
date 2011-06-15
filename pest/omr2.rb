#!/usr/bin/env ruby

# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: OMR (Optical Mark Recognition)
#
# Parses a set of files or a given directory and saves the results for
# each image/sheet into the given directory. Results are the corrected
# x/y values for all elements given in the input-sheet (rotation, off-
# set) and the answers (choice attributes for each
# group/question). Outputs images for each fill out free text field if
# specified.
#
# Call omr2.rb without arguments for list of possible/required arguments
#
# This is version 2 which assumes the 'corners' option is enabled.

cdir = File.dirname(__FILE__)

require 'base64'
require 'rubygems'
require 'optparse'
require 'yaml'
require 'pp'
require 'ftools'
require 'tempfile'

# This allows loading the custom ImageMagick/RMagick version if it has
# been built. We avoid starting rails (which is slow) by manually
# defining RAILS_ROOT because we know where it is relative to this file.
RAILS_ROOT = "#{cdir}/../web"
class Rails
  def self.root
    RAILS_ROOT
  end
end

require cdir + '/../lib/seee_config.rb'
require Seee::Config.file_paths[:rmagick]

require cdir + '/../lib/FunkyDBBits.rb'

require cdir + '/helper.boxtools.rb'
require cdir + '/helper.database.rb'
require cdir + '/helper.drawing.rb'
require cdir + '/helper.constants.rb'
require cdir + '/helper.misc.rb'

require cdir + '/../lib/AbstractForm.rb'
require cdir + '/helper.AbstractFormExtended.rb'
require cdir + '/../lib/RandomUtils.rb'

# Profiler. Uncomment code at the end of this file, too.
#~ require 'ruby-prof'
#~ RubyProf.start


class PESTOmr < PESTDatabaseTools
  include PESTDrawingTools

  # Finds the percentage of black/white pixels for the given rectangle
  # and image.
  def black_percentage(img_id, x, y, width, height)
    black = black_pixels(img_id, x, y, width, height)
    all = (width*height).to_f
    black/all*100.0
  end

  # Counts the black pixels in the given area and image.
  def black_pixels(img_id, x, y, width, height)
    # all hard coded values are for 300 DPI images. Adjust values here
    # to match actual scanned resolution
    x = (x*@dpifix).round
    y = (y*@dpifix).round
    width = (width*@dpifix).round
    height = (height*@dpifix).round

    # limit values that go beyond the available pixels
    return 0 if x >= @ilist[img_id].columns || y >= @ilist[img_id].rows
    x = x.make_min_0
    y = y.make_min_0
    width = Math.min(@ilist[img_id].columns - x, width)
    height = Math.min(@ilist[img_id].rows - y, height)
    return 0 if width <= 0 || height <= 0

    begin
      rect = @ilist[img_id].export_pixels(x, y, width, height, "G")
    rescue => e
      # This occurs when we specified invalid geometry: i.e. zero
      # width or height or requesting pixels outside the image.
      # Output some nice debugging data and just return 0.
      if @debug
        debug
        debug "    x: #{x.to_s.ljust(10)} y: #{y}".strip
        debug "    w: #{width.to_s.ljust(10)} h: #{height}".strip
      else
        debug "Critical Error: Invalid Geometry"
        @cancelProcessing = true
      end
      return 0
    end
    # this is faster than using NArray (needs conversion first) or
    # actually counting the objects using rect.count(QuantumRange)
    (rect - [Magick::QuantumRange]).size
  end

  # searches for the first line that has more than thres% black pixels
  # in the given area.
  # imd_id: image to process
  # tl: top left corner of the rectangle to search (specify an array with
  #     the first value being top, the second being left. Negative
  #     values are supported and will be interpreted as “from the bottom”
  #     or “from the right” respectively. [0,0] is in the upper left
  #     corner.
  # br: bottom right corner of the rectangle to search.
  # dir: The direction in which to search. Possible values: :left,
  #     :right, :up, :down
  # thres: the amount of pixels that ought to be black to trigger
  # prefer_2nd: if true, will look for a white bar in front of the black
  #     bar. This way you can start *on* a black area and get the next
  #     sensible result. Especially useful if there are black borders
  #     around the page due to misalignment while scanning.
  # Automatically prints debug output. A blue box marks a successful
  # search, a red one that the search failed.
  def search(img_id, tl, br, dir, thres, prefer_2nd = false, with_text = false)
    # round here, so we don't have to take care elsewhere
    tl.x = tl.x.round
    tl.y = tl.y.round
    br.x = br.x.round
    br.y = br.y.round

    raise "top and bottom have been switched" if !(tl[0] <= br[0])
    raise "left and right have been switched" if !(tl[1] <= br[1])

    # support negative values
    tl.x += @ilist[img_id].columns/@dpifix if tl.x < 0
    br.x += @ilist[img_id].columns/@dpifix if br.x < 0
    tl.y += @ilist[img_id].rows/@dpifix if tl.y < 0
    br.y += @ilist[img_id].rows/@dpifix if br.y < 0

    # determine along which axis to walk
    walk = (dir == :up || dir == :down) ? 1 : 0
    # switch search direction if applicable
    rev  = (dir == :up || dir == :left)
    # lines to consider
    vals = (tl[walk]..br[walk]).to_a
    vals.reverse! if rev

    w = br.x-tl.x
    h = br.y-tl.y

    vals.each do |i|
      if walk == 1 # down/up
        bp = black_percentage(img_id, tl.x, i, w, 1)
      else # left/right
        bp = black_percentage(img_id, i, tl.y, 1, h)
      end
      # search for a white seperator first
      prefer_2nd = false if bp < thres
      next if bp < thres || prefer_2nd

      # adjust box to match found coordinates
      tl.y = i if dir == :up
      br.y = i if dir == :down
      br.x = i if dir == :right
      tl.x = i if dir == :left
      draw_search_box(img_id, tl, br, "blue", dir, with_text)

      return i
    end
    draw_search_box(img_id, tl, br, "red", dir, with_text)
    nil
  end

  # Tries to locate a square box exactly that has been roughly located
  # using the position given by TeX and after applying offset+rotation.
  # Returns x, y coordinates that may be nil and also modifies the box
  # coordinates themselves (unless the box isn't found)
  def search_square_box(img_id, box)
    # TWEAK HERE
    box.width, box.height = 40, 40

    # Original position as given by TeX
    draw_transparent_box(img_id, box.tl, box.br, "yellow")
    tl = correct(img_id, [box.x, box.y])
    box.x, box.y = tl.x, tl.y

    # Where the box was put after correction
    draw_transparent_box(img_id, box.tl, box.br, "cyan", "", true)

    # Find the pre-printed box
    x = search(img_id, [box.tl.x-6, box.tl.y-10],
          [box.br.x - box.width/3*2, box.br.y+10], :right, 30, true)
    y = search(img_id, [box.tl.x-10, box.tl.y-6],
          [box.br.x+10, box.br.y - box.height/3*2], :down, 30, true)

    # If any coordinate couldn't be found, try again further away. Only
    # searches the newly added area.
    x = search(img_id, [box.tl.x-15, box.tl.y-10],
          [box.tl.x-6, box.br.y+10], :right, 30) if x.nil?
    y = search(img_id, [box.tl.x-10, box.tl.y-15],
          [box.br.x+10, box.tl.y-6], :down, 30) if y.nil?

    box.x = x unless x.nil?
    box.y = y unless y.nil?

    draw_text(img_id, [x-15,y+20], "black", box.choice)

    return x, y
  end

  # Finds and stores the black percentage for all boxes for the given
  # question in box.bp. Returns an array of box coordinates which
  # indicates which areas were being searched. Automatically runs more
  # thorough searches if no checkmarks are found.
  def process_square_boxes_blackness(img_id, question)
    # TWEAK HERE
    # thickness of the stroke
    stroke_width = 4
    # in certain cases the space around the printed box is searched.
    # _small describes the additional interval that should be excluded
    # around the box in pixels. Including the box in the black pixels
    # result makes it impossible to get good results. So don't set
    # this too low.
    # _large describes the area around the box to search.
    # In other words: the annulus with maximum norm and radii:
    # r = box/2 + _small  R = box/2 + _large
    around_small = 2
    around_large = 8

    debug_box = []

    question.boxes.each_with_index do |box, i|
      x, y = search_square_box(img_id, box)
      # Looks like the box doesn't exist. Assume it's empty.
      if x.nil? || y.nil?
        debug "Couldn't find box for page=#{img_id} box=#{box.choice}"
        debug "“#{question.qtext}”"
        debug "Assuming there is no box and no choice was made."
        box.bp = 0
        next
      end

      # inside the box
      tl = [x+stroke_width, y+stroke_width]
      br = [x+box.width-stroke_width, y+box.height-stroke_width]
      box.bp = black_percentage(img_id, tl.x, tl.y, br.x-tl.x, br.y-tl.y)
      debug_box[i] = [tl, br]
    end

    # reject all boxes with low fill grade to see if there are any
    # checkmarks. If not, look outside the boxes in case the user has
    # an odd checking style (e.g. circling the checkboxes)
    checked = question.boxes.select do |x|
      x.bp.between?(MIN_FILL_GRADE, MAX_FILL_GRADE)
    end
    return debug_box unless checked.empty?

    question.boxes.each_with_index do |box, i|
      ow = box.width+around_large
      oh = box.height+around_large
      outer = black_pixels(img_id, box.x-around_large,
                box.y-around_large, ow, oh)

      # this includes the pre-printed box as well
      iw = box.width+around_small
      ih = box.height+around_small
      inner = black_pixels(img_id, box.x-around_small,
                box.y-around_small, iw , ih)

      # add outer and existing black percentage
      box.bp = (box.bp + 100*(outer-inner).to_f/(ow*oh-iw*ih).to_f)/2

      debug_box[i] = [[box.x-around_large, box.y-around_large],
          [box.x+box.width+around_large, box.y+box.height+around_large]]
    end

    debug_box
  end

  # evaluates a single- or multiple choice question with square check-
  # boxes. Automatically corrects the boxes' position and computes the
  # black percentage and which boxes are checked and which are not. All
  # results are stored in the box themselves, but it also returns an
  # integer for single choice questions with the 'choice' attribute of
  # the selected box. Returns -1 if user intervention is required and 0
  # if no checkbox was selected. For multiple choice an array with the
  # choice attributes of the checked boxes is returned. This array may
  # be empty.
  def process_square_boxes(img_id, question)
    # calculate blackness for each box
    debug_box = process_square_boxes_blackness(img_id, question)

    # reject all boxes above maximum fill grade and mark them critical
    c = question.boxes.reject do |box|
      if box.bp > MAX_FILL_GRADE
        box.fill_critical = true
      end
      box.bp > MAX_FILL_GRADE
    end

    checked = c.reject { |x| x.bp < MIN_FILL_GRADE }
    checked.each { |box| box.is_checked = true }

    # don't do fancy stuff for multiple choice questions
    is_multi = question.db_column.is_a? Array
    result = if is_multi
      checked.collect { |box| box.choice }
    else # single choice question
      case checked.size
        # only one checkbox remains, so go for it
        when 1: checked.first.choice
        when 0: # no checkboxes. We're officially desperate now.
          # try again with lower standards
          checked = c.reject { |x| x.bp < DESPERATE_MIN_FILL_GRADE }
          checked.each { |box| box.is_checked = true; box.fill_critical = true }
          case checked.size
            when 1: checked.first.choice
            else     -1
          end
        else -1 # at least two boxes are checked, ask the user
      end # case
    end # else

    # print debug boxes
    question.boxes.each_with_index do |box, i|
      # this happens if a box couldn't be found. So don't debug it.
      next if debug_box[i].nil?

      color = "orange" # light orange; i.e. empty
      color = "red" if box.fill_critical # i.e. overfull
      color = "green" if box.is_checked # i.e. a nice checkmark
      color = "#5BF1B2" if box.fill_critical && box.is_checked # i.e. just barely filled

      draw_transparent_box(img_id, debug_box[i][0], debug_box[i][1],
        color, box.bp.round_to(1), true)
      draw_text(img_id, [box.x-20,box.y+40], "black", "X") if box.is_checked?
    end
    # print question's db_column left of question
    q = question.db_column
    draw_text(img_id, [10, debug_box.compact.first[0].y+10], "black", \
      (q.is_a?(Array) ? q.join(", ") : q))

    result
  end

  # Assumes a whole page for commentary. Crops a margin to remove any black
  # bars and then trims to any text if there.
  def typeTextWholePageParse(imgid, group)
    # Crop margins to remove black bars that appear due to rotated sheets
    s = 2*30*@dpifix
    i = @ilist[imgid]
    c = i.crop(Magick::CenterGravity, i.columns-s, i.rows-s).trim(true)
    return 0 if c.rows*c.columns < 500*@dpifix

    c = c.resize(0.4)
    step = 20*@dpifix
    thres = 40
    #   def black_pixels(x, y, width, height, img)
    # Find left border
    left = 0
    while left < c.columns
      break if black_pixels(left, 0, step, c.rows, c) > thres
      left += step
    end
    return 0 if left >= c.columns
    puts left

    # Find right border
    right = c.columns
    while right > 0
      break if black_pixels(right-step, 0, step, c.rows, c) > thres
      right -= step
    end
    return 0 if right < 0
    #puts right

    # Find top border
    top = 0
    while top < c.rows
      break if black_pixels(0, top, c.columns, step, c) > thres
      top += step
    end
    return 0 if top >= c.rows
    #puts top

    # Find bottom border
    bottom = c.rows
    while bottom > 0
      break if black_pixels(0, bottom-step, c.columns, step, c) > thres
      bottom -= step
    end
    return 0 if bottom < 0
    #puts bottom

    c.crop!(left-10, top-10, right-left+20, bottom-top+20, true)
    c.trim!(true)

    return 0 if c.rows*c.columns < 500*@dpifix

    filename = @path + "/" + File.basename(@currentFile, ".tif")
    filename << "_" + group.saveas + ".jpg"
    puts "  Saving Comment Image: " + filename if @verbose
    c.write filename

    return 1
  end

  # detects if a text box contains enough text and reports the result
  # (0 = no text, 1 = has text). It will automatically extract the
  # portion of the scanned sheet with the text and save it as .jpg.
  def process_text_box(img_id, question)
    # TWEAK HERE
    limit = 1000 * @dpifix
    bp = 0

    boxes = []
    question.boxes.each { |box| boxes << splitBoxes(box, 150, 150) }
    boxes.flatten!

    boxes.each do |box|
      tl = correct(img_id, box.tl)
      br = correct(img_id, box.br)
      box.x, box.y = tl.x, tl.y
      box.width, box.height =  br.x-tl.x, br.y-tl.y
      bp += black_pixels(img_id, box.x, box.y, box.width, box.height)
      color = bp > limit ? "green" : "red"
      draw_transparent_box(img_id, tl, br, color, bp, true)
      break if bp > limit
    end

    return 0 if bp <= limit

    # Save the comment as extra file if possible/required
    save_text_image(img_id, question.saveas, boxes)
    return 1
  end

  # Saves a given area (in form of a boxes array) for the current image.
  def save_text_image(img_id, save_as, boxes)
    return if save_as.nil? || save_as.empty?
    debug("    Saving Comment Image: #{save_as}", "save_image") if @verbose
    filename = @path + "/" + File.basename(@currentFile, ".tif")
    filename << "_" + save_as + ".jpg"
    x, y, w, h = calculateBounds(boxes)
    @ilist[img_id].crop(x, y, w, h).minify.write filename
    if @debug
      tl = [PAGE_WIDTH, PAGE_HEIGHT]
      boxes.each do |b|
        tl.x = [tl.x, b.x].min; tl.y = [tl.y, b.y].min
      end
      draw_text(img_id, tl, "green", "Saved as: #{filename}")
      draw_transparent_box(img_id, [x,y], [x+w,y+h], "#DBFFD8", "", true)
    end
    debug("    Saved Comment Image", "save_image") if @verbose
  end

  # Looks at each group listed in the yaml file and calls the appro-
  # priate functions to parse it. This is determined by looking at the
  # "type" attribute as specified in the YAML file. Results are saved
  # directly into the loaded sheet.
  def process_questions
    debug("  Recognizing Image", "recog_img") if @verbose

    0.upto(page_count - 1) do |i|
      if @doc.pages[i].questions.nil?
        debug "WARNING: Page does not contain any questions."
        debug "Are you sure there's a correct 'questions:' marker in the"
        debug "YAML file?"
        next
      end

      @doc.pages[i].questions.each do |g|
        @currentQuestion = g.db_column
        case g.type
          when "square" then
            g.value = process_square_boxes(i, g)
          when "text" then
            g.value = process_text_box(i, g)
          when "text_wholepage" then
            g.value = typeTextWholePageParse(i, g)
          else
            debug "    Unsupported type: " + g.type.to_s
        end
      end
    end
    debug("  Recognized Image", "recog_img") if @verbose
  end

  # Tries to find the corners on each corner of the page and stores them
  # in @corners. Only adds a corner if both parts of it are found.
  def locate_corners
    debug("  Locating corners…", "locate_corners") if @verbose
    @corners = []
    0.upto(page_count-1) do |i|
      @corners[i] = {:tr => [nil, nil], :tl => [nil, nil], \
                     :bl => [nil, nil], :br => [nil, nil]}
      # TWEAK HERE

      # top right corner
      x = search(i, [-1-200, 20], [-1, 20+150], :left, 30, true, true)
      y = search(i, [-20-150, 1], [-20, 1+150], :down, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:tr => [x,y]}) unless [x, y].any_nil?

      # top left corner
      x = search(i, [1, 20], [1+110, 20+150], :right, 30, true, true)
      y = search(i, [20, 1], [20+150, 1+90], :down, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:tl => [x,y]}) unless [x, y].any_nil?

      # bottom left corner
      x = search(i, [1, -60-150], [1+200, -40], :right, 30, true, true)
      y = search(i, [20, -1-150], [20+150, -1], :up, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:bl => [x,y]}) unless [x, y].any_nil?

      # bottom right corner
      x = search(i, [-1-200, -60-150], [-1, -40], :left, 30, true, true)
      y = search(i, [-20-150, -1-150], [-20, -1], :up, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:br => [x,y]}) unless [x, y].any_nil?

      # Debug prints that have only limited use
      #draw_line(i, @corners[i][:tl], @corners[i][:br], "yellow")
      #draw_line(i, @corners[i][:tr], @corners[i][:bl], "yellow")
      #draw_line(i, [0,0],    [PAGE_WIDTH, PAGE_HEIGHT], "yellow")
      #draw_line(i, [PAGE_WIDTH,0], [0, PAGE_HEIGHT], "yellow")

    end
    debug("  Located corners", "locate_corners") if @verbose
  end

  # Calculate the rotation from the corners. To do so, we calc the
  # angle between the diagonal of the page and the diagonal between
  # the detected corners. If possible, we do so for both diagonals to
  # reduce the measuring error.
  def determine_rotation
    debug "  Determining rotation" if @verbose
    @rotation = []
    0.upto(page_count-1) do |i|
      @rotation[i] = []
      e = @corners[i]

      if !e[:tl].any_nil? and !e[:br].any_nil?
        # it appears the top left to bottom right diagonal is fine
        adja = (e[:br].x - e[:tl].x).to_f
        oppo = (e[:br].y - e[:tl].y).to_f
        @rotation[i] << (Math.atan(adja/oppo) - PAGE_DIAG_ANGLE)
      end

      if !e[:tr].any_nil? and !e[:bl].any_nil?
        # it appears the top right to bottom left diagonal is fine
        adja = (e[:bl].x - e[:tr].x).to_f
        oppo = (e[:bl].y - e[:tr].y).to_f
        @rotation[i] << (PAGE_DIAG_ANGLE + Math.atan(adja/oppo))
      end

      if !e[:tl].any_nil? and !e[:bl].any_nil?
        # it appears the top left to bottom left side is fine
        adja = (e[:bl].y - e[:tl].y).to_f#.abs
        oppo = (e[:bl].x - e[:tl].x).to_f#.abs
        @rotation[i] << Math.atan(oppo/adja)
      end

      if !e[:tr].any_nil? and !e[:br].any_nil?
        # it appears the top right to bottom right side is fine
        adja = (e[:br].y - e[:tr].y).to_f
        oppo = (e[:br].x - e[:tr].x).to_f
        @rotation[i] << Math.atan(oppo/adja)
      end

      if @rotation[i].empty?
        debug "    Couldn't determine rotation for current sheet on page #{i+1}."
        debug "    This means that less than two corners could be detected."
        debug "    Marking #{File.basename(@currentFile)} as bizarre."
        @cancelProcessing = true
        next
      end

      debug("    #{i}: #{@rotation[i].join(", ")}") if @verbose
      @rotation[i] = @rotation[i].compact.sum / @rotation[i].size

      # We actually need to rotate in the other direction, but I am too
      # lazy to fix the code above. Feel free to FIXME
      @rotation[i] = (2*Math::PI - @rotation[i])



      # Draw a line near the top to be able to see in which direction
      # the rotation was detected. Draw a box around the main area to be
      # able to judge the rotation in comparison to the scanned sheet.
      draw_text(i, [200, 40], "green", "Rotation: #{(@rotation[i]*RAD2DEG)%360}°")
      draw_line(i, rotate(i, [10, 15]), rotate(i, [2470, 15]), "green")
      # top line
      draw_line(i, rotate(i, [120, 270]), rotate(i, [2420, 270]), "green")
      # left line
      draw_line(i, rotate(i, [120, 270]), rotate(i, [120, 3300]), "green")
      # bottom line
      draw_line(i, rotate(i, [120, 3300]), rotate(i, [2420, 3300]), "green")
      # right line
      draw_line(i, rotate(i, [2420, 3300]), rotate(i, [2420, 270]), "green")
    end
  end

  # corrects the rotation for a given point using the determined rotation
  def rotate(img_id, coord)
    return [nil, nil] if coord.any_nil?

    ox = PAGE_WIDTH/2.0
    oy = PAGE_HEIGHT/2.0
    rad = @rotation[img_id]

    newx = ox + (Math.cos(rad)*(coord.x-ox) - Math.sin(rad) * (coord.y-oy))
    newy = oy + (Math.sin(rad)*(coord.x-ox) + Math.cos(rad) * (coord.y-oy))

    [newx, newy]
  end

  def supplement_missing_corners
    0.upto(page_count-1) do |i|
      c = @corners[i]
      # top left corner
      # if top left is missing we can assume the tr-bl diagonal is fine,
      # otherwise we're doomed anyway.
      if c[:tl].any_nil?
        c[:tl].x ||= rotate(i, [c[:bl].x, c[:tr].y]).x
        c[:tl].y ||= rotate(i, [c[:bl].x, c[:tr].y]).y
        c[:tl] = rotate(i, c[:tl])
        draw_dot(i, c[:tl], "orange")
      end

      # top right corner (assume tl-br is fine)
      if c[:tr].any_nil?
        c[:tr].x ||= rotate(i, [c[:br].x, c[:tl].y]).x
        c[:tr].y ||= rotate(i, [c[:br].x, c[:tl].y]).y
        c[:tr] = rotate(i, c[:tr])
        draw_dot(i, c[:tr], "orange")
      end

      # bottom left corner (assume tl-br is fine)
      if c[:bl].any_nil?
        c[:bl].x ||= rotate(i, [c[:tl].x, c[:br].y]).x
        c[:bl].y ||= rotate(i, [c[:tl].x, c[:br].y]).y
        c[:bl] = rotate(i, c[:bl])
        draw_dot(i, c[:bl], "orange")
      end

      # bottom right corner (assume tr-bl is fine)
      if c[:br].any_nil?
        c[:br].x ||= rotate(i, [c[:tr].x, c[:bl].y]).x
        c[:br].y ||= rotate(i, [c[:tr].x, c[:bl].y]).y
        c[:br] = rotate(i, c[:br])
        draw_dot(i, c[:br], "orange")
      end

      # Connect found corners
      draw_line(i, c[:tr], c[:tl], "orange")
      draw_line(i, c[:tl], c[:bl], "orange")
      draw_line(i, c[:bl], c[:br], "orange")
      draw_line(i, c[:br], c[:tr], "orange")

      if c.any_nil?
        debug "    Couldn't supplement corners for current sheet on page #{i+1}."
        debug "    Marking this sheet as bizarre."
        @cancelProcessing = true
      end
    end
  end

  # Tries to determine the offset of the scanned image.
  def determine_offset
    debug "  Determining offset" if @verbose
    @offset = []
    0.upto(page_count-1) do |i|
      @offset[i] = {:l => nil, :r => nil, :b => nil, :t => nil}

      l = [@corners[i][:tl].x, @corners[i][:bl].x].compact
      r = [@corners[i][:tr].x, @corners[i][:br].x].compact
      t = [@corners[i][:tl].y, @corners[i][:tr].y].compact
      b = [@corners[i][:bl].y, @corners[i][:br].y].compact
      @offset[i][:l] = l.sum / l.size if l.size > 0
      @offset[i][:r] = r.sum / r.size if r.size > 0
      @offset[i][:t] = t.sum / t.size if t.size > 0
      @offset[i][:b] = b.sum / b.size if b.size > 0

      if @offset[i].any_nil?
        debug "    Couldn't determine offset for current sheet on page #{i+1}."
        debug "    Marking this sheet as bizarre."
        @cancelProcessing = true
        next
      end
    end
  end

  # translates (moves) a coordinate to the correct position using the
  # determined offset.
  def translate(img_id, coord)
    # TWEAK HERE
    move_top = 90
    move_left = 96

    o = @offset[img_id]
    c = @corners[img_id]


    px = coord.x/PAGE_WIDTH
    py = coord.y/PAGE_HEIGHT

    # these take the position into account instead of simply using the
    # arithmetic mean. Since the corners themselves are subjected to
    # rotation, this also corrects the rotation.
    off_top = c[:tl].y * (1-px) + c[:tr].y * px
    off_bottom = c[:bl].y * (1-px) + c[:br].y * px
    off_left = c[:tl].x * (1-py) + c[:bl].x * py
    off_right = c[:tr].x * (1-py) + c[:br].x * py

    x =  coord.x - move_left + off_left # 0.9995
    y = 0.997*(coord.y - move_top + off_top)

    # draw_text(img_id, [x,y], "blue", asd.round_to(4))

    [x, y]
  end

  # Translates and rotates a given coordinate (e.g. from TeX) into a
  # real coordinate (i.e. where it is located in the image). Requires
  # rotation and offset to be calculated beforehand.
  def correct(img_id, coord)
    #~ rotate(img_id, translate(img_id, coord))
    translate(img_id, coord)
  end

  # Does all of the overhead work required to be able to recognize an
  # image. More or less, it glues together all other functions and at
  # the end the result will be stored in the database
  def process_file(file)
    @cancelProcessing = false
    if !File.exists?(file) || File.zero?(file)
      debug "WARNING: File not found: " + file
      return
    end

    @currentFile = file

    start_time = Time.now
    debug("  Loading Image: #{file}", "loading_image") if @verbose

    # Load image and yaml sheet
    @doc = load_yaml_sheet
    @ilist = Magick::ImageList.new(file)

    if @debug
      # Create @draw element for each page for debugging
      @draw = []
      0.upto(page_count-1) do |i|
        create_drawable(i)
        draw_boilerplate(i, Dir.pwd, @omrsheet, file)
      end
    end

    debug("  Loaded Image", "loading_image") if @verbose

    # do the hard work
    locate_corners
    determine_rotation
    determine_offset
    supplement_missing_corners unless @cancelProcessing
    process_questions unless @cancelProcessing

    # Draw debugging image with thresholds, selected fields, etc.
    if @debug
      debug("  Applying debug drawing", "debug_print") if @verbose
      0.upto(page_count-1) do |i|
        begin
          # reduce black to light gray so transparent debug output may
          # have better visibility
          @ilist[i] = @ilist[i].level_colors("#ccc", "white")
          # draw a visible line to keep the pages apart
          draw_line(i, [0,0], [0, @ilist[i].rows], "black") if i > 0
          @draw[i].draw(@ilist[i])
        rescue; end
      end
      debug("  Applied drawing", "debug_print") if @verbose


      dbgFlnm = gen_new_filename(file, "_DEBUG.jpg")
      debug("  Saving Image: #{dbgFlnm}", "saving_image") if @verbose
      img = @ilist.append(false)
      img.write(dbgFlnm) { self.quality = 100 }
      debug("  Saved Image", "saving_image") if @verbose
    end

    if @cancelProcessing
      debug "  Something went wrong while recognizing this sheet."
      debug "  " + File.basename(file)
      return @test_mode # don't move the sheet if in test_mode
      dir = File.join(File.dirname(file).gsub(/\/[^\/]+$/, ""), "bizarre/")
      File.makedirs(dir)
      File.move(file, File.join(dir, File.basename(file)))
      return
    end

    # Output generated data
    store_results(@doc, file)
  end

  # stores the results from the given doc into the database and also
  # writes out the YAML file if in debug mode
  def store_results(yaml, filename)
    keys = Array.new
    vals = Array.new

    # Get barcode
    keys << "barcode"
    vals << find_barcode_from_path(filename).to_s

    keys << "path"
    vals << filename

    keys << "abstract_form"
    vals << Base64.encode64(Marshal.dump(yaml))

    yaml.questions.each do |q|
      next if q.type == "text" || q.type == "text_wholepage"
      next if q.db_column.nil?

      if q.db_column.is_a?(Array)
        q.db_column.each_with_index do |a, i|
          # The first answer starts with 1, but i is zero-based.
          # Therefore add 1 everytime to put the results in the
          # right columns.
          vals << (q.value == (i+1).to_s ? 1 : 0).to_s
          keys << a
        end
      else
        vals << (q.value.nil? ? 0 : Integer(q.value)).to_s
        keys << q.db_column
      end
    end

    q = "INSERT INTO #{yaml.db_table} ("
    q << keys.join(", ")
    q << ") VALUES ("
    # inserts right amount of question marks for easy
    # escaping
    q << (["?"]*(vals.size)).join(", ")
    q << ")"


    # only create YAMLs in debug and test mode
    if @debug || @test_mode
      fout = File.open(gen_new_filename(filename), "w")
      fout.puts YAML::dump(@doc)
      fout.close
    end

    # don't write to DB in test mode
    return if @test_mode
    begin
      dbh.do("DELETE FROM #{yaml.db_table} WHERE path = ?", filename)
      dbh.do(q, *vals)
    rescue DBI::DatabaseError => e
      debug "Failed to insert #{File.basename(filename)} into database."
      debug q
      debug "Error code: #{e.err}"
      debug "Error message: #{e.errstr}"
      debug "Error SQLSTATE: #{e.state}"
      debug
      debug "Aborting due to database error."
      exit 4
    rescue
      debug "Failed to insert #{File.basename(filename)} into database."
      debug "Aborting due to random error."
      exit 5
    end
  end

  # Helper function that determines where the parsed data should go
  def gen_new_filename(file, ending = ".yaml")
    return @path + "/" + File.basename(file, ".tif") + ending
  end

  # Checks for existing files and issues a warning if so. Returns a
  # list of non-existing files
  def remove_processed_images_from(files)
    debug "Checking for existing files" if @verbose

    oldsize = files.size
    dbh.execute("SELECT path FROM #{db_table}").each do |row|
      files -= row
    end
    if oldsize != files.size
      debug "  WARNING: #{oldsize-files.size} files already exist and have been skipped."
    end

    files
  end

  # Iterates a list of filenames and parses each. Checks for existing
  # files if told so.
  def process_file_list(files)
    overall_time = Time.now
    skipped_files = 0

    debug "Processing first of #{files.length} files"

    files.each_with_index do |file, i|
      # Processes the file and prints processing time
      file_time = Time.now

      percentage = (i.to_f/files.length*100.0).to_i
      debug("Processing File #{i}/#{files.length} (#{percentage}%)", "whole_file") if @verbose

      begin
        process_file(file)
      rescue => e
        debug "FAILED: #{file}"
        message = "\n\n\n\nFAILED: #{file}\n#{e.message}\n#{e.backtrace.join("\n")}"
        File.open("PEST_OMR_ERROR.log", 'a+') do |errlog|
          errlog.write(message)
        end
        debug "="*20
        debug "OMR is EXITING! Fix this issue before attemping again! (See PEST_OMR_ERROR.log)"
        debug message if @verbose
        exit 1
      end

      if @verbose
        debug("Processed file", "whole_file")
        debug
      end

      # Calculates and prints time remaining
      processed_files = i+1 - skipped_files
      if processed_files > 0
        time_per_file = (Time.now-overall_time)/processed_files.to_f
        remaining_files = (files.length-processed_files)
        timeleft = time_per_file*remaining_files/60.0
        if @verbose
          debug "Time remaining: #{timeleft.as_time}"
        else
          percentage = ((i+1).to_f/files.length*100.0).to_i
          debug "#{timeleft.as_time} left (#{percentage}%, #{i+1}/#{files.length})"
        end
      end
    end

    # Print some nice stats
    debug
    debug
    t = Time.now-overall_time
    f = files.length - skipped_files
    debug "Total Time: #{(t/60).as_time} (for #{f} files)"
    debug "(that's #{((t/f)/60).as_time} per file)"
  end

  # Parses the given OMR sheet and extracts globally interesting data
  # and ensures the database table exists.
  def parse_omr_sheet
    return unless @db_table.nil?
    debug "Parsing OMR sheet…"

    if !File.exists?(@omrsheet)
      debug "Couldn't find given OMR sheet (" + @omrsheet + ")"
      exit 6
    end
    # can’t use load_yaml_sheet here because it needs more dependencies
    # that are not yet available
    doc = YAML::load(File.read(@omrsheet))

    @page_count = doc.pages.count
    @db_table = doc.db_table
    if @db_table.nil?
      debug "ERROR: OMR Sheet #{@omrsheet} doesn’t define in which table the results should be stored. Add a db_table value to the form in the YAML root."
      debug "Exiting."
      exit 2
    end

    create_table_if_required(doc) unless @test_mode
  end

  # returns the db_table that is used for the currently processed form
  def db_table
    parse_omr_sheet if @db_table.nil?
    @db_table
  end

  # returns the amount of pages that are defined in the currently
  # processed form
  def page_count
    parse_omr_sheet if @page_count.nil?
    @page_count
  end

  # Loads the YAML file and converts LaTeX's scalepoints into pixels
  def load_yaml_sheet
    # it is faster create new YAMLs by marshaling them instead of having
    # to parse them again.
    return Marshal.load(@omrsheet_parsed) if @omrsheet_parsed
    doc = YAML::load(File.read(@omrsheet))
    doc.pages.each do |p|
      next if p.questions.nil?
      p.questions.each do |q|
        if q.saveas && q.saveas.scan(/[a-z0-9-]/i).join != q.saveas
        debug "saveas attribute for #{@omrsheet} question #{q.db_column} contains invalid characters. Only a-z, A-Z, 0-9 and hyphens are allowed."
          exit 7
        end
        next if q.boxes.nil?
        q.boxes.each do |b|
          b.width  = b.width/SP_TO_PX*@dpifix unless b.width.nil?
          b.height = b.height/SP_TO_PX*@dpifix unless b.height.nil?
          b.x = b.x / SP_TO_PX*@dpifix
          b.y = PAGE_HEIGHT*@dpifix - (b.y / SP_TO_PX*@dpifix)
        end
      end
    end
    @omrsheet_parsed = Marshal.dump(doc)
    doc
  end

  # Reads the commandline arguments and does some basic sanity checking
  # Returns non-empty list of files to be processed.
  def parse_commandline
    # Define useful default values
    @omrsheet,  @path  = nil, nil
    @overwrite, @debug = false, false
    @test_mode = false
    dpi        = 300.0
    @cores     = 1

    # Option Parser
    begin
      opt = OptionParser.new do |opts|
        opts.banner = "Usage: omr2.rb --omrsheet omrsheet.yaml --path workingdir [options] [file1 file2 …]"
        opts.separator("")
        opts.separator("REQUIRED ARGUMENTS:")
        opts.on("-s", "--omrsheet OMRSHEET", "Path to the OMR Sheet that should be used to parse the sheets") { |sheet| @omrsheet = sheet }

        opts.on("-p", "--path WORKINGDIR", "Path to the working directory where all the output will be saved.", "All image paths are relative to this.") { |path| @path = path.chomp("/") }

        opts.separator("")
        opts.separator("OPTIONAL ARGUMENTS:")
        opts.on("-o", "--overwrite", "Specify if you want to output files in the working directory to be overwritten") { @overwrite = true }

        opts.on("-c", "--cores CORES", Integer, "Number of cores to use (=processes to start)", "This spawns a new ruby process for each core, so if you want to stop processing you need to kill each process. If there are no other ruby instances running, type this command: killall ruby") { |c| @cores = c }

        opts.on("-q", "--dpi DPI", Float, "The DPI the sheets have been scanned with.", "This value is autodetected ONCE. This means you cannot mix sheets with different DPI values") { |dpi| @dpifix = dpi/300.0 }

        opts.on("-v", "--verbose", "Print more output (sets cores=1)") { @verbose = true }

        opts.on("-d", "--debug", "Specify if you want debug output as well.", "Will write a JPG file for each processed sheet to the working directory; marked with black percentage values, thresholds and selected fields.", "Be aware, that this makes processing about four times slower.", "Automatically activates debug database.") { @debug = true }

        opts.on("-t", "--testmode", "Sets useful values for running tests.", "Disables database access and stops files from being moved to bizarre/.") { @test_mode = true }

        opts.on( '-h', '--help', 'Display this screen' ) { puts opts; exit }
      end
      opt.parse!
    rescue
      puts "Parsing arguments didn't work. Please check your commandline is correct."
      puts
      opt.parse(["-h"]) if !@path || !@omrsheet
      exit
    end

    # For some reason, the option parser doesn't halt the app over
    # missing mandatory arguments, so we do have to check manually
    opt.parse(["-h"]) if !@path || !@omrsheet

    if !File.directory?(@path)
      debug "Given directory #{@path} does not exist, skipping."
      exit
    end

    # if debug is activated, use SQLite database instead.
    set_debug_database if @debug

    # Verbose and multicore processing don't really work together,
    # the output is just too ugly.
    if @verbose && @cores > 1
      @cores = 1
      debug "WARNING: Disabled multicore processing because verbose is enabled."
    end

    files = []
    # If no list of files is given, look at the given working
    # directory.
    if ARGV.empty?
      files = Dir.glob(@path + "/*.tif")
      if files.empty?
        debug "No tif images found in #{@path}. Exiting."
        exit
      end
    else
      ARGV.each { |f| files << @path + "/" + f }
    end

    # remove files that have already been processed, unless the user
    # wants them to be overwritten
    files = remove_processed_images_from(files) if !@overwrite
    if files.empty?
      debug "All files have been processed already. Exiting."
      exit
    end

    files
  end

  # Splits the given file and reports the status of each sub-process.
  def delegate_work(files)
    debug "Owning certain software, #{@cores} sheets at a time"
    splitFiles = files.chunk(@cores)

    path  = " -p " + @path.gsub(/(?=\s)/, "\\")
    sheet = " -s " + @omrsheet.gsub(/(?=\s)/, "\\")
    d = @debug      ? " -d " : " "
    db = @test_mode ? " -t " : " "
    o = @overwrite  ? " -o " : " "

    tmpfiles, threads, exit_codes = [], [], []

    splitFiles.each_with_index do |f, corecount|
      next if f.empty?

      tmp = Tempfile.new("pest-omr-status-#{corecount}").path
      tmpfiles << tmp

      list = ""
      f.each { |x| list << " " + File.basename(x).gsub(/(?=\s)/, "\\") }
      threads << Thread.new do
        `ruby #{File.dirname(__FILE__)}/omr2.rb #{sheet} #{path} #{db} #{d} #{o} #{list} > #{tmp}`
        exit_codes[corecount] = $?.exitstatus
      end
    end

    STDOUT.sync = false
    begin
      print_progress(tmpfiles)
    rescue SystemExit, Interrupt
      debug
      debug "Halting processing threads..."
      threads.each { |x| x.kill }
      debug "All threads stopped. Exiting."
      STDOUT.flush
      exit
    end
    exit_codes
  end

  # prints the progress that is printed into the given tmpfiles.
  # Returns once all tmpfiles are deleted
  def print_progress(tmpfiles)
    last_length = 0
    while Thread.list.length > 1
      tmpfiles.reject! { |x| !File.exists?(x) }
      print "\r" + " "*last_length + "\r"
      last_length = 0
      tmpfiles.each_with_index do |x, i|
        dat = `tail -n 1 #{x}`.strip
        dat = dat.ljust([dat.length+10, 60].max) if i < tmpfiles.size - 1
        print dat
        last_length += dat.length
      end

      STDOUT.flush
      sleep 1
    end
    puts
    debug "Done."
  end

  # Report if a 'unsuitable' ImageMagick version will be used
  def check_magick_version
    return if Magick::Magick_version.include?("Q8")
    debug
    debug "WARNING: ImageMagick version does not seem to be compiled"
    debug "with --quantum-depth=8. This will make processing slower."
    debug "Try running 'rake magick:all' to build a custom version"
    debug "with all neccessary flags set. Version as reported:"
    debug Magick::Magick_version
    debug
  end

  # Class Constructor
  def initialize
    # required for multi core processing. Otherwise the data will
    # not be written to the tempfiles before the sub-process exits.
    STDOUT.sync = true
    files = parse_commandline
    ensure_database_access unless @test_mode
    check_magick_version

    # Let other ruby instances do the hard work for multi core...
    if @cores > 1
      exit_codes = delegate_work(files)
      if exit_codes.sum > 0
        debug "Some of the work processes failed for some reason."
        debug "Consult PEST_OMR_ERROR.log for more information."
        debug "Exitcodes are: #{exit_codes.join(", ")}"
      end
    # or do it in this instance for single core processing
    else
      # Unless set manually, grab a sample image and use it to
      # calculate the DPI
      if @dpifix.nil?
        list = Magick::ImageList.new(files[0])
        @dpifix = list[0].dpifix
      end

      # All set? Ready, steady, parse!
      parse_omr_sheet

      # Iterates over the given filenames and recognizes them
      begin
        process_file_list(files)
      rescue Interrupt, SystemExit => e
        ex = e.status if e && e.is_a?(SystemExit)
        debug
        debug "Caught exit or interrupt signal. Exiting. #{ex}"
        exit 3
      end
    end
  end
end

PESTOmr.new()

#~ result = RubyProf.stop
#~ printer = RubyProf::FlatPrinter.new(result)
#~ printer.print(STDOUT, 0)
