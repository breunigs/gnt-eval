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
# Call omr.rb without arguments for list of possible/required arguments
#
# This is version 2 which assumes the 'edges' option is enabled.

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

require cdir + '/helper.array.rb'
require cdir + '/helper.boxtools.rb'
require cdir + '/helper.database.rb'
require cdir + '/helper.constants.rb'
require cdir + '/helper.misc.rb'

require cdir + '/../lib/AbstractForm.rb'
require cdir + '/helper.AbstractFormExtended.rb'
require cdir + '/../lib/RandomUtils.rb'

# Profiler. Uncomment code at the end of this file, too.
#~ require 'ruby-prof'
#~ RubyProf.start


class PESTOmr < PESTDatabaseTools
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
        puts
        puts "x: #{x.to_s.ljust(10)} y: #{y}".strip
        puts "\nw: #{width.to_s.ljust(10)} h: #{height}".strip
        #puts "g: " + @currentQuestion
      else
        puts "Critical Error: Invalid Geometry"
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
  # tl: top left edge of the rectangle to search (specify an array with
  #     the first value being top, the second being left. Negative
  #     values are supported and will be interpreted as “from the bottom”
  #     or “from the right” respectively. [0,0] is in the upper left
  #     corner.
  # br: bottom right edge of the rectangle to search.
  # dir: The direction in which to search. Possible values: :left,
  #     :right, :up, :down
  # thres: the amount of pixels that ought to be black to trigger
  # prefer_2nd: if true, will look for a white bar in front of the black
  #     bar. This way you can start *on* a black area and get the next
  #     sensible result. Especially useful if there are black borders
  #     around the page due to misalignment while scanning.
  # Automatically prints debug output. A blue box marks a successful
  # search, a red one that the search failed.
  def search(img_id, tl, br, dir, thres, prefer_2nd = false)
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
      draw_search_box(img_id, tl, br, "blue", dir)

      return i
    end
    draw_search_box(img_id, tl, br, "red", dir)
    nil
  end

  # draws a transparent rectangle for the area and highlights one side
  # of the border, depending on search direction. Also inserts an arrow
  # automatically to hint in which direction was being searched.
  def draw_search_box(img_id, tl, br, color, dir)
    return if !@debug or tl.any_nil? or br.any_nil?
    t = { :right => "→", :left => "←", :up => "↑", :down => "↓" }
    draw_transparent_box(img_id, tl, br, color, t[dir])
    tl.x = br.x if dir == :right
    br.x = tl.x if dir == :left
    tl.y = br.y if dir == :down
    br.y = tl.y if dir == :up
    draw_line(img_id, tl, br, color)
  end

  # draws a colored transparent box for the given coordinates to the
  # image at @ilist[img_id]. If text is given, it will be drawn in the
  # approx. center of the box.
  def draw_transparent_box(img_id, tl, br, color, text = nil, border = false)
    return if !@debug or tl.any_nil? or br.any_nil?
    @draw[img_id].fill(color)
    @draw[img_id].stroke(color)
    @draw[img_id].fill_opacity(0.1)
    @draw[img_id].stroke_opacity(border ? 0.3 : 0)
    @draw[img_id].rectangle(tl.x, tl.y, br.x, br.y)
    return if text.nil?

    @draw[img_id].stroke_opacity(1)
    xmid = tl.x + (br.x - tl.x)/2.0
    ymid = tl.y + (br.y - tl.y)/2.0
    m = @draw[img_id].get_type_metrics(text.to_s)

    @draw[img_id].text(xmid-m.width/2.0, ymid, text.to_s)
  end

  # draws a line from and to the given coordinates on @ilist[img_id].
  def draw_line(img_id, top_left, bottom_right, color)
    return if !@debug || top_left.any_nil? || bottom_right.any_nil?
    @draw[img_id].stroke(color)
    @draw[img_id].stroke_width(1)
    @draw[img_id].stroke_opacity(1)
    @draw[img_id].line(top_left.x, top_left.y, bottom_right.x, bottom_right.y)
  end

  # draws a small dot (actually a circle) at the specified coordinates
  # coord: top, left
  def draw_dot(img_id, coord, color)
    return if !@debug or coord.any_nil?
    @draw[img_id].stroke(color)
    @draw[img_id].stroke_width(1)
    @draw[img_id].stroke_opacity(1)
    @draw[img_id].fill_opacity(0)
    @draw[img_id].circle(coord.x, coord.y, coord.x+3, coord.y)
  end

  # This function encapsulates the process for determining if a set of
  # square boxes is checked and returns the appropriate answer.
  def typeSquareParse(imgid, group)
    checks = []
    first = 0
    inner = (SQUARE_SIZE - 2*SQUARE_STROKE)*@dpifix

    group.boxes.each do |box|
      x, y = calcSkew(imgid, box.x, box.y)

      # Find the pre-printed box
      mx = search_from_left(x, y, (SQUARE_SEARCH[0]/2)*@dpifix, (SQUARE_SEARCH[1])*@dpifix, 50, @ilist[imgid]).makePos

      # If we get the right end of the search area returned, we
      # probably didn't find anything, but stopped searching. It
      # is more likely that we started search too far to the right
      # in the first place. Thus, try again starting "more left".
      # Similar if we succeed right away: We know we are somewhere
      # on the line, but we need the left start.
      maxCorr = 3
      interval = (SQUARE_SEARCH[0]/2)*@dpifix
      while (mx == x+interval || mx == x) && maxCorr > 0 && x > 0
        x = (x-(SQUARE_STROKE*2)*@dpifix).makePos
        mx = search_from_left(x, y, interval, (SQUARE_SEARCH[1])*@dpifix, 50, @ilist[imgid])
        maxCorr -= 1
      end

      # Hopefully we have found a vertical line of the box by now.
      # However, we do not yet know if we found the left or right
      # one. Therefore we peek to the left and right and try to
      # find the other vertical bar of the box.
      # width, height, left, right, top, bottom
      w = SQUARE_STROKE*@dpifix*4
      h = SQUARE_SEARCH[1]*@dpifix
      l = mx - (SQUARE_SIZE + SQUARE_STROKE)*@dpifix
      r = mx + (SQUARE_SIZE - SQUARE_STROKE)*@dpifix
      t = y - SQUARE_STROKE*@dpifix

      lbp = black_percentage(l, t, w, h, @ilist[imgid])
      rbp = black_percentage(r, t, w, h, @ilist[imgid])

      # if this is true, we found the right bar. Since we need the
      # left one, we start a search once more
      if lbp > rbp
        mx = search_from_left(l, t, w, h, 50, @ilist[imgid])
      end

      # Draw where the correct line has been found
      if @debug
        @draw.stroke("green")
        @draw.fill("green")
        @draw.line(mx, t, mx, t+h)
      end

      my = search_from_top(mx, y, SQUARE_SEARCH[0]*@dpifix, (SQUARE_SEARCH[1]/2)*@dpifix, 50, @ilist[imgid]).makePos
      # This is not a typo:    ^^
      # If we managed to find left already, we have better chances
      # of finding the correct top. If we found a wrong left we're
      # doomed anyway

      maxCorr = 3
      interval = (SQUARE_SEARCH[1]/2)*@dpifix
      while my == y + interval && maxCorr > 0 && y > 0
        y = (y-(SQUARE_STROKE*2)*@dpifix).makePos
        my = search_from_top(mx, y, SQUARE_SEARCH[0]*@dpifix, interval, 50, @ilist[imgid])
        maxCorr -= 1
      end
#~
      #~ tbp = black_percentage(mx, my-h, w, h, @ilist[imgid])
      #~ bbp = black_percentage(mx, my, w, h, @ilist[imgid])
      #~ if tbp > bbp
        #~ my = search_from_top(mx, my-h, SQUARE_SEARCH[0]*@dpifix, interval, 50, @ilist[imgid])
      #~ end

      # Save corrected values to sheet so the FIX component doesn't
      # need to re-calculate this
      box.x = x
      box.y = y

      # Used for debugging below
      box.mx = mx
      box.my = my

      # First check for the inner pixels. If there are any, we al-
      # most absolutely have a checkmark
      bp = black_percentage(mx + SQUARE_STROKE*@dpifix, my + SQUARE_STROKE*@dpifix, inner, inner, @ilist[imgid])

      # Save the raw value to the yaml
      box.bp = bp

      # Draw the rotation-correction-guidelines and the search
      # radius for each checkbox
      if @debug
        @draw.stroke("black")
        @draw.fill("black")
        @draw.fill_opacity(1)
        @draw.text(x+(SQUARE_SEARCH[0]+5)*@dpifix, y+20*@dpifix, ((bp * 100).round.to_f / 100).to_s)

        @draw.line(x - 100*@dpifix, y, x + 100*@dpifix, y)
        @draw.line(x, y - 100*@dpifix, x, y + 200*@dpifix)

        if first == 0 && !group.db_column.is_a?(Array)
          @draw.text((x - 50*@dpifix).makePos, y + 20*@dpifix, group.db_column)
        end
        first += 1

        if group.db_column.is_a?(Array)
          @draw.text((x - 50*@dpifix).makePos, y + 20*@dpifix, group.db_column[first-1])
        end

        @draw.stroke("blue")
        @draw.fill_opacity(0)
        @draw.rectangle(x, y, x + SQUARE_SEARCH[0]*@dpifix, y + SQUARE_SEARCH[1]*@dpifix)
      end
    end

    # At first, use very high thresholds so that question that are
    # clearly marked are not affected by small errors due to dirt or
    # imperfect scanning. If no checkmark is found, lower the thres-
    # hold each time. This makes it more prone to false-positives,
    # but at least keeps them to a minimum on questions that do not
    # need such a low limit. The last entry will be marked as "low
    # threshold".
    thresholds = [3.5, 1.5, 0.5]
    # This ensures that single boxes won't get checked because of
    # dirt. This might result in undetected checkmarks but no answer
    # is preferable over a wrong one.
    thresholds.pop if group.boxes.size == 1
    # Upper limit. All checked boxes with a black percentage above
    # this threshold are disregarded if and only if there is more
    # than one checkmark. Single choice questions above this thres-
    # hold are marked as failed and thus presented to the user.
    # Multiple choice questions will be handled like there was no
    # upper limit if this occurs.
    thres_max = 90

    low_threshold = false
    thresholds.each do |t|
      low_threshold = t == thresholds.last
      group.boxes.each do |box|
        checks << box if box.bp > t
      end
      break if checks.size >= 1
    end

    result = nil

    # it's a single choice question and the upper limit has been
    # reached. Mark it as failed.
    if group.boxes.size == 1 && checks.size == 1 && checks[0].bp > thres_max
      result = -1
    end

    # it's a multiple choice question. Remove all checkmarks that
    # are above the threshold but only if there are at least two
    # checkmarks (catches the case where someone used a fat marker)
    if group.boxes.size >= 2 && checks.size >= 2
      del = checks.find_all { |x| x.bp > thres_max }
      del.each { |d| d.fill_critical = true }
      checks -= del
      # We lost all checkmarks… let's ask the user
      result = -1 if checks.empty?
    end

    # Cover all normal cases
    result = case checks.length
      when 0 then 0
      when 1 then checks[0].choice
      else -1
    end unless result

    # store for each box if it was checked
    checks.each { |c| c.is_checked = true }
    # store for each box if it was selected with a low threshld
    checks.each { |c| c.fill_critical = true } if low_threshold

    # Draws the red/green/yellow boxes for each answer
    if @debug
      group.boxes.each do |box|
        # only draw a yellow box if the checkmark has been
        # dismissed due to its high black percentage.
        color = box.bp > thres_max ? "yellow" : "red"
        color = "green" if checks.include?(box)
        @draw.fill(color)
        @draw.fill_opacity(0.3)
        @draw.stroke(color)
        @draw.rectangle(box.mx + SQUARE_STROKE*@dpifix, box.my + SQUARE_STROKE*@dpifix, box.mx + SQUARE_STROKE*@dpifix + inner, box.my + SQUARE_STROKE*@dpifix + inner)
      end
    end

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

  def process_text_box(img_id, question)
    # TWEAK HERE
    limit = 1000 * @dpifix
    bp = 0

    boxes = []
    question.boxes.each { |box| boxes << splitBoxes(box, 150, 150) }
    boxes.flatten!

    boxes.each do |box|
      tl = correct(img_id, [box.x, box.y])
      br = correct(img_id, [box.x+box.width, box.y+box.height])
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
    return if question.save_as.empty?
    puts "  Saving Comment Image: #{save_as}" if @verbose
    filename = @path + "/" + File.basename(@currentFile, ".tif")
    filename << "_" + save_as + ".jpg"
    x, y, w, h = calculateBounds(boxes, group)
    @ilist[img_id].crop(x, y, w, h).minify.write filename
  end

  # This function tries to determine if a text field is filled out
  # If so and the "saveas" attribute is specified the comment will be
  # saved to the given filename.
  def typeTextParse(imgid, group)
    bp = 0
    limit = 1000*@dpifix
    boxes = []
    # Split up the text fields into many smaller boxes. Is is needed
    # for rotated sheets as the box would otherwise cover preprinted
    # areas and produce a false positive. If cut, large areas would
    # be missing and if would produce false negatives.
    # Splitting the boxes allows to circumvent this while still
    # being reasonable fast.
    group.boxes.each { |box| boxes << splitBoxes(box, 150, 150) }
    boxes.flatten!
    boxes.each do |box|
      # LaTeX' coordinates are shifted by default for some reason.
      # Fix this here.
      x, y = calcSkew(imgid, box.x + 60*@dpifix, box.y + 20*@dpifix)

      # We may need to shrink the detection rectangle on severe
      # rotations. Otherwise it would cover pre-printed text which
      # chould result in a false positive
      skewx, skewy = x - box.x, y - box.y

      # Save corrected values to sheet so the FIX component
      # doesn't need to re-calculate this
      box.x = x
      box.y = y

      bp += black_pixels(x, y, box.width, box.height, @ilist[imgid], true)

      if @debug
        color = bp > limit ? "green" : "red"
        @draw.fill(color)
        @draw.fill_opacity(0.3)
        @draw.stroke(color)
        @draw.rectangle(x, y, x + box.width, y + box.height)
        @draw.stroke("black")
        @draw.fill_opacity(1)
        @draw.text(x+5*@dpifix, y+20*@dpifix, bp.to_s)
      end

      break if bp > limit
    end

    # Save the comment as extra file if possible/required
    if !group.saveas.empty? && bp > limit
      if @verbose
        print "  Saving Comment Image: "
        puts group.saveas
      end
      filename = @path + "/" + File.basename(@currentFile, ".tif")
      filename << "_" + group.saveas + ".jpg"
      x, y, w, h = calculateBounds(boxes, group)
      @ilist[imgid].crop(x, y, w, h).minify.write filename
    end

    # use "1" for yes and "0" for no text (= no choice)
    return bp > limit ? 1 : 0
  end

  # Looks at each group listed in the yaml file and calls the appro-
  # priate functions to parse it. This is determined by looking at the
  # "type" attribute as specified in the YAML file. Results are saved
  # directly into the loaded sheet.
  def process_questions
    start_time = Time.now
    puts "  Recognizing Image" if @verbose

    0.upto(page_count - 1) do |i|
      if @doc.pages[i].questions.nil?
        puts "WARNING: Page does not contain any questions."
        puts "Are you sure there's a correct 'questions:' marker in the"
        puts "YAML file?"
        next
      end

      @doc.pages[i].questions.each do |g|
        @currentQuestion = g.db_column
        case g.type
          when "square" then
            #g.value = typeSquareParse(i, g)
          when "text" then
            #g.value = typeTextParse(i, g)
            g.value = process_text_box(i, g)
          when "text_wholepage" then
            #g.value = typeTextWholePageParse(i, g)
          else
            puts "Unsupported type: " + g.type.to_s
        end
      end
    end

    puts "  (took: " + (Time.now-start_time).to_s + " s)" if @verbose
  end

  def locate_edges
    @edges = []
    0.upto(page_count-1) do |i|
      @edges[i] = {}
      # TWEAK HERE

      # top right edge
      x = search(i, [-1-200, 20], [-1, 20+150], :left, 20, true)
      y = search(i, [-20-150, 1], [-20, 1+150], :down, 20, true)
      draw_dot(i, [x, y], "red") unless [x, y].any_nil?
      @edges[i].merge!({:tr => [x,y]})

      # top left edge
      x = search(i, [1, 20], [1+200, 20+150], :right, 20, true)
      y = search(i, [20, 1], [20+150, 1+150], :down, 20, true)
      draw_dot(i, [x, y], "red") unless [x, y].any_nil?
      @edges[i].merge!({:tl => [x,y]})

      # bottom left edge
      x = search(i, [1, -60-150], [1+200, -40], :right, 20, true)
      y = search(i, [20, -1-150], [20+150, -1], :up, 20, true)
      draw_dot(i, [x, y], "red") unless [x, y].any_nil?
      @edges[i].merge!({:bl => [x,y]})

      # bottom right edge
      x = search(i, [-1-200, -60-150], [-1, -40], :left, 20, true)
      y = search(i, [-20-150, -1-150], [-20, -1], :up, 20, true)
      draw_dot(i, [x, y], "red") unless [x, y].any_nil?
      @edges[i].merge!({:br => [x,y]})

      # Debug prints that have only limited use
      #draw_line(i, @edges[i][:tl], @edges[i][:br], "yellow")
      #draw_line(i, @edges[i][:tr], @edges[i][:bl], "yellow")
      #draw_line(i, [0,0],    [2480, 3508], "yellow")
      #draw_line(i, [2480,0], [0, 3508], "yellow")

    end
  end

  # Calculate the rotation from the edges. To do so, we calc the
  # angle between the diagonal of the page and the diagonal between
  # the detected edges. If possible, we do so for both diagonals to
  # reduce the measuring error.
  def determine_rotation
    perfect_abs = 4296.09869532812 # Math.sqrt(2480**2 + 3508**2)
    @rotation = []
    0.upto(page_count-1) do |i|
      @rotation[i] = nil
      e = @edges[i]
      if !e[:tl].any_nil? and !e[:br].any_nil?
        # it appears the top left to bottom right diagonal is fine
        measured = [e[:br].x-e[:tl].x, e[:br].y-e[:tl].y]
        measured_abs = Math.sqrt(measured.x**2 + measured.y**2)
        scalar = measured.x*2480 + measured.y*3508
        @rotation[i] = Math.acos(scalar/(measured_abs*perfect_abs))
      end

      if !e[:tr].any_nil? and !e[:bl].any_nil?
        # it appears the top right to bottom left diagonal is fine
        measured = [e[:bl].x-e[:tr].x, e[:bl].y-e[:tr].y]
        measured_abs = Math.sqrt(measured.x**2 + measured.y**2)
        scalar = measured.x*2480 - measured.y*3508
        rot = Math::PI - Math.acos(scalar/(measured_abs*perfect_abs))
        @rotation[i] = @rotation[i].nil? ? rot : (@rotation[i]+rot)/2
      end

      # We actually need to rotate in the other direction, but I am too
      # lazy to fix the code above. Feel free to FIXME
      @rotation[i] = 2*Math::PI - @rotation[i]

      if @rotation[i].nil?
        puts "Couldn't determine rotation for current sheet on page #{i+1}."
        puts "This means that no diagonal edges could be detected."
        puts "Marking this sheet as bizarre."
        @cancelProcessing = true
      end

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

  def determine_offset
    @offset = []
    0.upto(page_count-1) do |i|
      @offset[i] = {}

      l = [@edges[i][:tl].x, @edges[i][:bl].x].compact
      r = [@edges[i][:tr].x, @edges[i][:br].x].compact
      t = [@edges[i][:tl].y, @edges[i][:tr].y].compact
      b = [@edges[i][:bl].y, @edges[i][:br].y].compact
      @offset[i][:l] = l.sum / l.size
      @offset[i][:r] = r.sum / r.size
      @offset[i][:t] = t.sum / t.size
      @offset[i][:b] = b.sum / b.size
    end
  end

  # corrects the rotation for a given point using the determined rotation
  def rotate(img_id, coord)
    ox = 2480.0/2.0
    oy = 3508.0/2.0
    rad = @rotation[img_id]

    newx = ox + (Math.cos(rad)*(coord.x-ox) - Math.sin(rad) * (coord.y-oy))
    newy = oy + (Math.sin(rad)*(coord.x-ox) + Math.cos(rad) * (coord.y-oy) )

    [newx, newy]
  end

  def translate(img_id, coord)
    # expected offset from top left corner
    # TWEAK HERE
    off_top = 0
    off_left = -60

    o = @offset[img_id]
    x = (o[:r]-o[:l]) * (coord.x/2480.0) + off_left
    y = (o[:b]-o[:t]) * (coord.y/3508.0) + off_top

    [x, y]
  end

  def correct(img_id, coord)
    rotate(img_id, translate(img_id, coord))
  end

  # Does all of the overhead work required to be able to recognize an
  # image. More or less, it glues together all other functions and
  # saves the output to an YAML named like the input image.
  def parseFile(file)
    @cancelProcessing = false
    if !File.exists?(file) || File.zero?(file)
      puts "WARNING: File not found: " + file
      return
    end

    @currentFile = file

    start_time = Time.now
    print "  Loading Image: " + file if @verbose

    # Load image and yaml sheet
    @doc = loadYAMLsheet
    @ilist = Magick::ImageList.new(file)
    puts " (took: " + (Time.now-start_time).to_s + " s)" if @verbose

    if @debug
      # Create @draw element for each page for debugging
      @draw = []
      0.upto(page_count-1) do |i|
        @draw[i] = Magick::Draw.new
        @draw[i].font_weight = 100
        @draw[i].pointsize = 20*@dpifix
      end
    end

    # do the hard work
    locate_edges
    determine_offset
    determine_rotation
    process_questions

    # Draw debugging image with thresholds, selected fields, etc.
    if @debug
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

      start_time = Time.now
      img = @ilist.append(false)
      #~ img = img.scale(0.5)
      dbgFlnm = getNewFileName(file, "_DEBUG.jpg")
      print "  Saving Image: " + dbgFlnm if @verbose
      img.write(dbgFlnm) { self.quality = 75 }
      puts " (took: " + (Time.now-start_time).to_s + " s)" if @verbose
    end
    #exit # FIXME

    if @cancelProcessing
      puts
      puts "  Found boxes to be out of bounds. Moving to bizzare:"
      puts "  " + File.basename(file)
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

    begin
      #FIXME
      #dbh.do("DELETE FROM #{yaml.db_table} WHERE path = ?", filename)
      #dbh.do(q, *vals)
    rescue DBI::DatabaseError => e
      puts "Failed to insert #{File.basename(filename)} into database."
      puts q
      puts "Error code: #{e.err}"
      puts "Error message: #{e.errstr}"
      puts "Error SQLSTATE: #{e.state}"
      puts
      puts "Aborting."
      exit
    end

    # only create YAMLs in debug mode
    return unless @debug
    fout = File.open(getNewFileName(filename), "w")
    fout.puts YAML::dump(@doc)
    fout.close
  end

  # Finds if a given page for the currently loaded @doc requires
  # knowledge about offset and rotation.
  def pageNeedsPositionData(id)
    throw :documentHasTooFewPages_CheckForMissingPageBreak if @doc.pages[id].nil?
    q = @doc.pages[id].questions
    !(q.nil? || q.empty? || q.any? {|x| x.type == "text_wholepage"})
  end

  # Helper function that determines where the parsed data should go
  def getNewFileName(file, ending = ".yaml")
    return @path + "/" + File.basename(file, ".tif") + ending
  end

  # Checks for existing files and issues a warning if so. Returns a
  # list of non-existing files
  def remove_processed_images_from(files)
    puts "Checking for existing files" if @verbose

    oldsize = files.size
    dbh.execute("SELECT path FROM #{db_table}").each do |row|
      files -= row
    end
    puts "  WARNING: #{oldsize-files.size} files already exist and have been skipped." if oldsize != files.size

    files
  end

  # Iterates a list of filenames and parses each. Checks for existing
  # files if told so and does all that "processing time" yadda yadda.
  def parseFilenames(files)
    i = 0
    f = Float.induced_from(files.length)
    allfile = f.to_i.to_s

    overall_time = Time.now
    skippedFiles = 0

    files.each do |file|
      # Processes the file and prints processing time
      file_time = Time.now
      i += 1

      curfile = i.to_i.to_s
      percentage = (i/f*100.0).to_i.to_s

      if @verbose
        print "Processing File " + curfile + "/" + allfile
        puts  " (" + percentage + "%)"
      end

      begin
        parseFile(file)
      rescue => e
        puts "FAILED: #{file}"
        File.open("PEST_OMR_ERROR.log", 'a+') do |errlog|
        errlog.write("\n\n\n\nFAILED: #{file}\n#{e.message}\n#{e.backtrace.join("\n")}")
        end
        puts "="*20
        puts "OMR is EXITING! Fix this issue before attemping again! (See PEST_OMR_ERROR.log)"
        exit
      end

      if @verbose
        puts "  Processing Time: " + (Time.now-file_time).to_s + " s"
        puts ""
      end

      # Calculates and prints time remaining
      rlFiles = Float.induced_from(i - skippedFiles)
      if rlFiles > 0
        timePerFile = (Time.now-overall_time)/rlFiles
        filesLeft = (files.length-rlFiles)
        timeleft = ((timePerFile*filesLeft/60)+0.5).to_i.to_s
        if @verbose
          puts "Time remaining: " + timeleft + " m"
        else
          puts timeleft + " m left (" + percentage + "%, " + curfile + "/" + allfile + ")"
        end
      end
    end

    # Print some nice stats
    puts
    puts
    puts
    puts
    t = Time.now-overall_time
    f = files.length - skippedFiles
    print "Total Time: " + (t/60).to_s + " m "
    puts "(for " + f.to_s + " files)"
    puts "(that's " + (t/f).to_s + " s per file)"
  end

  # Parses the given OMR sheet and extracts globally interesting data
  # and ensures the database table exists.
  def parse_omr_sheet
    return unless @db_table.nil?

    if !File.exists?(@omrsheet)
      puts "Couldn't find given OMR sheet (" + @omrsheet + ")"
      exit
    end
    # can’t use loadYAMLsheet here because it needs more dependencies
    # that are not yet available
    doc = YAML::load(File.read(@omrsheet))

    @page_count = doc.pages.count
    @db_table = doc.db_table
    if @db_table.nil?
      puts "ERROR: OMR Sheet #{@omrsheet} doesn’t define in which table the results should be stored. Add a db_table value to the form in the YAML root."
      puts "Exiting."
      exit 1
    end

    create_table_if_required(doc)
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

  # creates the database table as defined by the given YAML document.
  def create_table_if_required(f)
    # Note that the barcode is only unique for each CourseProf, but
    # not for each sheet. That's why path is used as unique key.
    q = "CREATE TABLE #{f.db_table} ("

    f.questions.each do |quest|
      next if quest.db_column.nil?
      if quest.db_column.is_a?(Array)
        quest.db_column.each do |a|
          q << "#{a} INTEGER, "
        end
      else
        q << "#{quest.db_column} INTEGER, "
      end
    end

    q << "path VARCHAR(255) NOT NULL UNIQUE, "
    q << "barcode INTEGER default NULL, "
    q << "abstract_form TEXT default NULL "
    q << ");"

    begin
      dbh.do(q)
      puts "Created #{f.db_table}"
    rescue => e
      # There is no proper method supported by MySQL, PostgreSQL and
      # SQLite to find out if a table already exists. So, if above
      # command failed because the table exists, selecting something
      # from it should work fine. If it doesn’t, print an error message.
      begin
        dbh.do("SELECT * FROM #{f.db_table}")
      rescue
        puts "Note: Creating #{name} (table: #{f.db_table}) failed. Possible causes:"
        puts "* SQL backend is down/misconfigured"
        puts "* used SQL query is not supported by your SQL backend"
        puts "Query was #{q}"
        print "Error: "
        pp e
        exit
      end
    end
  end

  # Loads the YAML file and converts LaTeX's scalepoints into pixels
  def loadYAMLsheet
    # it is faster create new YAMLs by marshaling them instead of having
    # to parse them again.
    return Marshal.load(@omrsheet_parsed) if @omrsheet_parsed
    doc = YAML::load(File.read(@omrsheet))
    doc.pages.each do |p|
      next if p.questions.nil?
      p.questions.each do |q|
        if q.saveas && q.saveas.scan(/[a-z0-9-]/i).join != q.saveas
          puts "saveas attribute for #{@omrsheet} question #{q.db_column} contains invalid characters. Only a-z, A-Z, 0-9 and hyphens are allowed."
          exit
        end
        next if q.boxes.nil?
        q.boxes.each do |b|
          b.width  = b.width/SP_TO_PX*@dpifix unless b.width.nil?
          b.height = b.height/SP_TO_PX*@dpifix unless b.height.nil?
          b.x = b.x / SP_TO_PX*@dpifix
          b.y = 3508.0*@dpifix - (b.y / SP_TO_PX*@dpifix)
        end
      end
    end
    @omrsheet_parsed = Marshal.dump(doc)
    doc
  end

  # Reads the commandline arguments and does some basic sanity checking
  # Returns non-empty list of files to be processed.
  def parseArguments
    # Define useful default values
    @omrsheet  = nil
    @path    = nil
    @overwrite = false
    @debug   = false
    dpi    = 300.0
    @cores   = 1

    # Option Parser
    opt = OptionParser.new do |opts|
      opts.banner = "Usage: omr.rb --omrsheet omrsheet.yaml --path workingdir [options] [file1 file2 ...]"
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

      opts.on("-d", "--debug", "Specify if you want debug output as well.", "Will write a JPG file for each processed sheet to the working directory; marked with black percentage values, thresholds and selected fields.", "Be aware, that this makes processing about four times slower.") { @debug = true }

      opts.on( '-h', '--help', 'Display this screen' ) { puts opts; exit }
    end
    opt.parse!

    # For some reason, the option parser doesn't halt the app over
    # missing mandatory arguments, so we do have to check manually
    if !@path || !@omrsheet
      opt.parse(["-h"])
    end

    if !File.directory?(@path)
      puts "Given directory #{@path} does not exist, skipping."
      exit
    end

    # if debug is activated, use SQLite database instead
    #set_debug_database if @debug # FIXME FIXME

    # Verbose and multicore processing don't really work together,
    # the output is just too ugly.
    if @verbose && @cores > 1
      @cores = 1
      puts "WARNING: Disabled multicore processing because verbose is enabled."
    end

    files = []
    # If no list of files is given, look at the given working
    # directory.
    if ARGV.empty?
      files = Dir.glob(@path + "/*.tif")
      if files.empty?
        puts "No tif images found in #{@path}. Exiting."
        exit
      end
    else
      ARGV.each { |f| files << @path + "/" + f }
    end

    # remove files that have already been processed, unless the user
    # wants them to be overwritten
    files = remove_processed_images_from(files) if !@overwrite
    if files.empty?
      puts "All files have been processed already. Exiting."
      exit
    end

    files
  end

  # Splits the given file and reports the status of each sub-process.
  def delegateWork(files)
    puts "Owning certain software, " + @cores.to_s + " sheets at a time"
    splitFiles = files.chunk(@cores)

    path = " -p " + @path.gsub(/(?=\s)/, "\\")
    sheet = " -s " + @omrsheet.gsub(/(?=\s)/, "\\")
    d = @debug   ? " -d " : " "
    v = @verbose   ? " -v " : " "
    o = @overwrite ? " -o " : " "

    tmpfiles = []
    threads = []

    corecount = 0
    splitFiles.each do |f|
      corecount += 1
      next if f.empty?

      tmp = Tempfile.new("pest-omr-status-#{corecount}")
      tmpfiles << tmp

      list = ""
      f.each { |x| list << " " + File.basename(x).gsub(/(?=\s)/, "\\") }
      # This is the amount of spaces the output of newly
      # spawned instances are indented. Quite useful to keep
      # the console output readable.
      #~ i = " -i " + (corecount*35).to_s
      threads << Thread.new do
        `ruby #{File.dirname(__FILE__)}/omr.rb #{sheet} #{path} #{v} #{d} #{o} #{list} &> #{tmp.path}`
      end
    end
    puts

    STDOUT.sync = false
    begin
      print_progress(tmpfiles)
    rescue SystemExit, Interrupt
      puts
      puts
      puts "Halting processing threads..."
      threads.each { |x| x.kill }
      puts "Exiting."
      STDOUT.flush
      exit
    end
  end

  # prints the progress that is printed into the given tmpfiles.
  # Returns once all tmpfiles are deleted
  def print_progress(tmpfiles)
    while Thread.list.length > 1
      tmpfiles.reject! { |x| !File.exists?(x) }
      print "\r"
      tmpfiles.each_with_index do |x, i|
        dat = `tail -n 1 #{x.path}`.strip
        if i == tmpfiles.size - 1
          print dat
        else
          print dat.ljust([dat.length+10, 50].max)
        end
      end

      STDOUT.flush
      sleep 1
    end
    puts "Done."
  end

  # Report if a 'unsuitable' ImageMagick version will be used
  def check_magick_version
    return if Magick::Magick_version.include?("Q8")
    puts
    puts "WARNING: ImageMagick version does not seem to be compiled"
    puts "with --quantum-depth=8. This will make processing slower."
    puts "Try running 'rake magick:all' to build a custom version"
    puts "with all neccessary flags set. Version as reported:"
    puts Magick::Magick_version
    puts
  end

  # Class Constructor
  def initialize
    # required for multi core processing. Otherwise the data will
    # not be written to the tempfiles before the sub-process exits.
    STDOUT.sync = true
    files = parseArguments
    ensure_database_access
    check_magick_version

    # Let other ruby instances do the hard work for multi core...
    if @cores > 1
      delegateWork(files)
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
        parseFilenames(files)
      rescue SystemExit, Interrupt
        puts
        puts "Exiting."
        exit
      end
    end
  end
end

PESTOmr.new()

#~ result = RubyProf.stop
#~ printer = RubyProf::FlatPrinter.new(result)
#~ printer.print(STDOUT, 0)
