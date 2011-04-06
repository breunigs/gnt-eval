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
  def blackPercentage(x, y, width, height, img)
    black = blackPixels(x, y, width, height, img)
    all = (width*height).to_f
    black/all*100.0
  end

  # Counts the black pixels in the given area and image.
  # Set fix to true if out-ouf-bounds requests should not trigger an
  # error and be handled gracefully
  def blackPixels(x, y, width, height, img, fix = false)
    if fix
      return 0 if x >= img.columns || y >= img.rows
      x = x.makePos
      y = y.makePos
      width = Math.min(img.columns - x, width)
      height = Math.min(img.rows - y, height)
      return 0 if width <= 0 || height <= 0
    end
    begin
      rect = img.export_pixels(x, y, width, height, "G")
    rescue
      # This occurs when we specified invalid geometry: i.e. zero
      # width or height or requesting pixels outside the image.
      # Output some nice debugging data and just return 0.
      if @debug
        puts
        puts "x: #{x.to_s.ljust(10)} y: #{y}".strip
        puts "\nw: #{width.to_s.ljust(10)} h: #{height}".strip
        puts "g: " + @currentQuestion
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

  # This function finds the first line of pixels whose black-% is
  # above the given threshold. <code>left</code> and <code>top</code>
  # mark the start of the search area, <code>width</code> and
  # <code>height</code> how large the search radius should be.
  # Searches in 1 pixel steps from left to left+width and returns that
  # value as soon as the 1-pixel-line is above <code>threshold</code>.
  # <code>img</code> is the image to search.
  # Does not take rotation or offset into account.
  def findFirstPixelsFromLeft(left, top, width, height, threshold, img)
    left.upto(left + width) do |i|
      bp = blackPercentage(i, top, 1, height, img)
      return i if bp > threshold
    end
    return left + width
  end

  # same as <code>findFirstPixelsFromLeft</code>, but starts searching
  # from the top and returns a vertical/y-value
  def findFirstPixelsFromTop(left, top, width, height, threshold, img)
    top.upto(top + height) do |i|
      bp = blackPercentage(left, i, width, 1, img)
      return i if bp > threshold
    end
    return top + height
  end

  # Finds the rotation for each page seperately. Does so by finding
  # the start of the text/questions on top and bottom of each page.
  # These values are then used to calulate the angle the sheet is
  # rotated.
  def findRotation
    sLeft = (  40*@dpifix).to_i
    sTop  = ( 180*@dpifix).to_i
    sBot  = (2650*@dpifix).to_i
    width = ( 250*@dpifix).to_i
    height= ( 300*@dpifix).to_i

    start_time = Time.now
    print "  Correcting Rotation" if @verbose
    @rad = []
    @ilist.each_with_index do |img,index|
      next unless pageNeedsPositionData(index)
      topstart = findFirstPixelsFromLeft(sLeft, sTop, width, height, 9, img)
      botstart = findFirstPixelsFromLeft(sLeft, sBot, width, height, 9, img)

      # Calculate angle in radians
      @rad << Math.atan((botstart - topstart).to_f/(sBot - sTop - height).to_f)

      if @debug
        # Careful! This draws into the images before they are
        # completely recognized. If it intersects with a checkbox
        # the results will be wrong
        draw = Magick::Draw.new
        draw.font_weight = 100
        draw.pointsize = 20*@dpifix
        draw.fill("blue")
        draw.stroke("blue")
        draw.line(topstart, sTop, topstart, sTop+height)
        draw.line(botstart, sBot, botstart, sBot+height)
        draw.text(10*@dpifix, 35*@dpifix, (@rad.last*RAD2DEG).to_s)

        draw.fill_opacity(0.05)
        draw.stroke_opacity(0)
        draw.rectangle(sLeft, sTop, topstart, sTop+height)
        draw.rectangle(sLeft, sBot, botstart, sBot+height)
        draw.fill_opacity(1)
        draw.stroke_opacity(1)

        draw.draw(img)
      end
    end

    puts " (took: " + (Time.now-start_time).to_s + " s)" if @verbose
  end

  # This finds out how large the white "border" around the actual
  # sheet is, in order to get a fixed point of reference (i.e. the
  # top left corner is the same for every sheet)
  def findOffset
    start_time = Time.now
    print "  Determining Offset" if @verbose

    # FIXME: Move this somewhere else in order to support more than
    # two pages without changing code

    # X/Y values in the YAML files are relative to this corner
    # These values mark the coordinates where the objects used
    # for detection should actually be in a perfectly scanned
    # document. They are hardcoded, since they never change.
    leftcut = [168*@dpifix, 168*@dpifix]
    topcut = [(145-3)*@dpifix, (139-3)*@dpifix]

    # This will contain the offset for each sheet
    @leftoff = [0,0]
    @topoff = [0,0]

    # Use different thresholds for each page to lessen the chance of
    # failing due to some black pixels
    leftThres = [9, 9]
    topThres = [20, 20]

    lTop    = ( 180*@dpifix).to_i
    lBot    = (2650*@dpifix).to_i
    lLeft   = (  40*@dpifix).to_i
    lWidth  = ( 500*@dpifix).to_i
    lHeight = ( 300*@dpifix).to_i
    tLeft   = (2000*@dpifix).to_i
    tTop    = (  40*@dpifix).to_i
    tWidth  = ( 400*@dpifix).to_i
    tHeight = ( 500*@dpifix).to_i
    0.upto(page_count-1) do |i|
      next unless pageNeedsPositionData(i)
      left = findFirstPixelsFromLeft(lLeft, lTop, lWidth, lHeight, leftThres[i], @ilist[i])
      top  =  findFirstPixelsFromTop(tLeft, tTop, tWidth, tHeight, topThres[i], @ilist[i])

      # Draw the lines where the threshold was found
      if @debug
        draw = Magick::Draw.new
        draw.font_weight = 100
        draw.pointsize = 20*@dpifix
        draw.fill("magenta")
        draw.stroke("magenta")
        draw.line(left, lTop, left, lTop+lHeight)
        draw.line(tLeft, top, tLeft+tWidth, top)
        draw.text(10*@dpifix, 15*@dpifix, left.to_s + " x " + top.to_s)

        draw.fill_opacity(0.05)
        draw.stroke_opacity(0)
        draw.rectangle(lLeft, lTop, left, lTop+lHeight)
        draw.rectangle(tLeft, tTop, tLeft+tWidth, top)
        draw.fill_opacity(1)
        draw.stroke_opacity(1)
      end

      # The offset detection is done at points that are affected
      # by rotation. We take this into account here.
      #~ top +=  top - calcSkew(i, tLeft + tWidth/2, top)[1]

      # Depending on the direction of the rotation either a point
      # at the top or bottom of the sheet should be used as refer-
      # ence.
      if @rad[i]*RAD2DEG > 0
        left += left - calcSkew(i, left, lTop/2)[0]
        top +=  top- calcSkew(i, tLeft + tWidth, top)[1]
      else
        left += left - calcSkew(i, left, lBot)[0]
        top +=  top - calcSkew(i, tLeft + tWidth/2, top)[1]
      end

      @leftoff[i] = left - leftcut[i]
      @topoff[i]  = top  -  topcut[i]

      # Draw the rotation-corrected lines
      if @debug
        draw.fill("magenta")
        draw.stroke("magenta")
        draw.line(left, lTop, left, lTop+lHeight)
        draw.line(tLeft, top, tLeft+tWidth, top)
        # This affects offset detection. I will die a miserable
        # death for this
        draw.draw(@ilist[i])
      end
    end

    puts " (took: " + (Time.now-start_time).to_s + " s)" if @verbose
  end

  # For a given image id and perfect coordinates, this calculates the
  # corrected coordinates by taking offset and angle into account.
  def calcSkew(imgid, ox, oy)
    ox += @leftoff[imgid]
    oy += @topoff[imgid]
    x = ox * Math.cos(@rad[imgid]) + oy * Math.sin(@rad[imgid])
    y = oy * Math.cos(@rad[imgid]) - ox * Math.sin(@rad[imgid])
    return x.round.makePos, y.round.makePos
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
      mx = findFirstPixelsFromLeft(x, y, (SQUARE_SEARCH[0]/2)*@dpifix, (SQUARE_SEARCH[1])*@dpifix, 50, @ilist[imgid]).makePos

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
        mx = findFirstPixelsFromLeft(x, y, interval, (SQUARE_SEARCH[1])*@dpifix, 50, @ilist[imgid])
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

      lbp = blackPercentage(l, t, w, h, @ilist[imgid])
      rbp = blackPercentage(r, t, w, h, @ilist[imgid])

      # if this is true, we found the right bar. Since we need the
      # left one, we start a search once more
      if lbp > rbp
        mx = findFirstPixelsFromLeft(l, t, w, h, 50, @ilist[imgid])
      end

      # Draw where the correct line has been found
      if @debug
        @draw.stroke("green")
        @draw.fill("green")
        @draw.line(mx, t, mx, t+h)
      end

      my = findFirstPixelsFromTop(mx, y, SQUARE_SEARCH[0]*@dpifix, (SQUARE_SEARCH[1]/2)*@dpifix, 50, @ilist[imgid]).makePos
      # This is not a typo:    ^^
      # If we managed to find left already, we have better chances
      # of finding the correct top. If we found a wrong left we're
      # doomed anyway

      maxCorr = 3
      interval = (SQUARE_SEARCH[1]/2)*@dpifix
      while my == y + interval && maxCorr > 0 && y > 0
        y = (y-(SQUARE_STROKE*2)*@dpifix).makePos
        my = findFirstPixelsFromTop(mx, y, SQUARE_SEARCH[0]*@dpifix, interval, 50, @ilist[imgid])
        maxCorr -= 1
      end
#~
      #~ tbp = blackPercentage(mx, my-h, w, h, @ilist[imgid])
      #~ bbp = blackPercentage(mx, my, w, h, @ilist[imgid])
      #~ if tbp > bbp
        #~ my = findFirstPixelsFromTop(mx, my-h, SQUARE_SEARCH[0]*@dpifix, interval, 50, @ilist[imgid])
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
      bp = blackPercentage(mx + SQUARE_STROKE*@dpifix, my + SQUARE_STROKE*@dpifix, inner, inner, @ilist[imgid])

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
    #   def blackPixels(x, y, width, height, img)
    # Find left border
    left = 0
    while left < c.columns
      break if blackPixels(left, 0, step, c.rows, c) > thres
      left += step
    end
    return 0 if left >= c.columns
    puts left

    # Find right border
    right = c.columns
    while right > 0
      break if blackPixels(right-step, 0, step, c.rows, c) > thres
      right -= step
    end
    return 0 if right < 0
    #puts right

    # Find top border
    top = 0
    while top < c.rows
      break if blackPixels(0, top, c.columns, step, c) > thres
      top += step
    end
    return 0 if top >= c.rows
    #puts top

    # Find bottom border
    bottom = c.rows
    while bottom > 0
      break if blackPixels(0, bottom-step, c.columns, step, c) > thres
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

      bp += blackPixels(x, y, box.width, box.height, @ilist[imgid], true)

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
  def recoImage
    start_time = Time.now
    puts "  Recognizing Image" if @verbose

    max = Math::min(@ilist.length, page_count) - 1

    0.upto(max) do |i|
      if @debug
        # Create @draw element the type*Parse functions can
        # access
        @draw = Magick::Draw.new
        @draw.font_weight = 100
        @draw.pointsize = 20*@dpifix
      end

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
            # width, height and threshold are predefined for squares
            g.value = typeSquareParse(i, g)
          when "text" then
            g.value = typeTextParse(i, g)
          when "text_wholepage" then
            g.value = typeTextWholePageParse(i, g)
          else
            puts "Unsupported type: " + g.type.to_s
        end
      end

      # Apply what the type*Parse functions drew
      begin
        @draw.draw(@ilist[i]) if @debug
      rescue
        puts "  Nothing to draw :(" if @debug and @verbose
      end
    end

    puts "  (took: " + (Time.now-start_time).to_s + " s)" if @verbose
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

    # do the hard work
    findRotation
    findOffset
    recoImage

    # Draw debugging image with thresholds, selected fields, etc.
    if @debug
      start_time = Time.now
      img = @ilist.append(false)
      #~ img = img.scale(0.5)
      dbgFlnm = getNewFileName(file, "_DEBUG.jpg")
      print "  Saving Image: " + dbgFlnm if @verbose
      img.write(dbgFlnm) { self.quality = 75 }
      puts " (took: " + (Time.now-start_time).to_s + " s)" if @verbose
    end

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
      dbh.do("DELETE FROM #{yaml.db_table} WHERE path = ?", filename)
      dbh.do(q, *vals)
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
        if q.saveas
          q.saveas.scan(/[a-z0-9-]/i).join != q.saveas
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
      puts "Specified PATH is not a directory"
      exit
    end

    # if debug is activated, use SQLite database instead
    set_debug_database if @debug

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
      printProgress(tmpfiles)
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
  def printProgress(tmpfiles)
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
