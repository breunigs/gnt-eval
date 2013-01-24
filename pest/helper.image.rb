# encoding: utf-8

# Provides general features to work with the scanned images and the
# associated YAML files. Offers the ability to detect rotation and
# offset, as well as features to search for black areas in the sheet.

cdir = File.dirname(__FILE__)
require cdir + '/helper.constants.rb'
require cdir + '/helper.misc.rb' # also load rmagick
require cdir + '/helper.drawing.rb'

module PESTImageTools
  include PESTDrawingTools

  # Finds the percentage of black/white pixels for the given rectangle
  # and image.
  def black_percentage(img_id, x, y, width, height)
    black = black_pixels(img_id, x, y, width, height)
    all = (width*height).to_f
    black/all*100.0
  end

  # counts the black pixels in the given area and image. Expects an
  # RMagick image as the first parameter.
  def black_pixels_img(image, x, y, width, height)
    # all hard coded values are for 300 DPI images. Adjust values here
    # to match actual scanned resolution
    x = (x*dpifix).round
    y = (y*dpifix).round
    width = (width*dpifix).round
    height = (height*dpifix).round

    # limit values that go beyond the available pixels
    return 0 if x >= image.columns || y >= image.rows
    x = x.make_min_0
    y = y.make_min_0
    width = Math.min(image.columns - x, width)
    height = Math.min(image.rows - y, height)
    return 0 if width <= 0 || height <= 0

    begin
      rect = image.export_pixels(x, y, width, height, "G")
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

  # Counts the black pixels in the given area and image. The first
  # parameter should be an integer which specifies the page of the
  # loaded image.
  def black_pixels(img_id, x, y, width, height)
    black_pixels_img(@ilist[img_id], x, y, width, height)
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
    raise "top and bottom have been switched" if !(tl[0] <= br[0])
    raise "left and right have been switched" if !(tl[1] <= br[1])

    # support negative values
    tl.x += @ilist[img_id].columns/dpifix if tl.x < 0
    br.x += @ilist[img_id].columns/dpifix if br.x < 0
    tl.y += @ilist[img_id].rows/dpifix if tl.y < 0
    br.y += @ilist[img_id].rows/dpifix if br.y < 0

    # round here, so we don't have to take care elsewhere
    tl.x = tl.x.round
    tl.y = tl.y.round
    br.x = br.x.round
    br.y = br.y.round

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

  def corner_angle(page_num, where)
    case where
      when :tl
        a = @corners[page_num][:tr].vector_diff(@corners[page_num][:tl])
        b = @corners[page_num][:bl].vector_diff(@corners[page_num][:tl])
      when :tr
        a = @corners[page_num][:br].vector_diff(@corners[page_num][:tr])
        b = @corners[page_num][:tl].vector_diff(@corners[page_num][:tr])
      when :bl
        a = @corners[page_num][:tl].vector_diff(@corners[page_num][:bl])
        b = @corners[page_num][:br].vector_diff(@corners[page_num][:bl])
      when :br
        a = @corners[page_num][:tr].vector_diff(@corners[page_num][:br])
        b = @corners[page_num][:bl].vector_diff(@corners[page_num][:br])
      else
        raise "Invalid position given."
    end

    return (Math::acos(a.dot_product(b) / (a.eucledian_norm * b.eucledian_norm)) / Math::PI * 180)
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
      x = search(i, [-1-200, 35], [-1, 35+150], :left, 30, true, true)
      y = search(i, [-40-150, 1], [-40, 1+150], :down, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:tr => [x,y]}) unless [x, y].any_nil?

      # top left corner
      x = search(i, [1, 35], [1+110, 35+150], :right, 30, true, true)
      y = search(i, [40, 1], [40+150, 1+150], :down, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:tl => [x,y]}) unless [x, y].any_nil?

      # bottom left corner
      x = search(i, [1, -50-150], [1+200, -30], :right, 30, true, true)
      y = search(i, [40, -1-150], [40+150, -1], :up, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:bl => [x,y]}) unless [x, y].any_nil?

      # bottom right corner
      x = search(i, [-1-200, -50-150], [-1, -30], :left, 30, true, true)
      y = search(i, [-40-150, -1-150], [-40, -1], :up, 30, true, true)
      draw_dot(i, [x, y], "red")
      @corners[i].merge!({:br => [x,y]}) unless [x, y].any_nil?

      len_l = (@corners[i][:bl][1] - @corners[i][:tl][1] - CORNER_HEIGHT).abs rescue len_l = nil
      len_r = (@corners[i][:br][1] - @corners[i][:tr][1] - CORNER_HEIGHT).abs rescue len_r = nil
      len_t = (@corners[i][:tr][0] - @corners[i][:tl][0] - CORNER_WIDTH).abs rescue len_t = nil
      len_b = (@corners[i][:br][0] - @corners[i][:bl][0] - CORNER_WIDTH).abs rescue len_b = nil

      # try to remove the corner which deviates very much from the
      # expected position
      c = nil
      c = corner_angle(i, :tl) > corner_angle(i, :tr) ? :tr : :tl if len_t && len_t >= CORNER_DEVIATION
      c = corner_angle(i, :bl) > corner_angle(i, :br) ? :br : :bl if len_b && len_b >= CORNER_DEVIATION
      c = corner_angle(i, :tl) > corner_angle(i, :bl) ? :bl : :tl if len_l && len_l >= CORNER_DEVIATION
      c = corner_angle(i, :tr) > corner_angle(i, :br) ? :br : :tr if len_r && len_r >= CORNER_DEVIATION
      if c
        debug("  Removing corner #{c} on page #{i} because it is so far off.") if @verbose
        @corners[i][c] = [nil, nil]
      end

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
    determine_rotation
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

  # translates (moves) a coordinate to the correct position using the
  # determined offset. In a perfectly scanned document, these values
  # should be equal to the printed distances in the top left corner. You
  # can use rake testhelper:debug_samplesheets to generate those. Note
  # that this also corrects rotation since the edges are subject to
  # rotation themselves.
  def translate(img_id, coord)
    # TWEAK HERE
    move_top = 58
    move_left = 62

    c = @corners[img_id]

    px = coord.x/PAGE_WIDTH
    py = coord.y/PAGE_HEIGHT

    # these take the position into account instead of simply using the
    # arithmetic mean. Since the corners themselves are subjected to
    # rotation, this also corrects the rotation.
    off_top = c[:tl].y * (1-px) + c[:tr].y * px
    #off_bottom = c[:bl].y * (1-px) + c[:br].y * px
    off_left = c[:tl].x * (1-py) + c[:bl].x * py
    #off_right = c[:tr].x * (1-py) + c[:br].x * py

    x = coord.x - move_left + off_left
    y = coord.y - move_top + off_top

    x += @auto_correction_horiz
    y += @auto_correction_vert

    [x, y]
  end

  alias :correct :translate

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

  def dpifix
    raise "Please load an image before accessing DPI." if @ilist.nil? && @dpifix.nil?
    @dpifix ||= @ilist[0].dpifix
    @dpifix
  end

  # Loads the YAML file and converts LaTeX's scalepoints into pixels
  def load_yaml_sheet(omrsheet)
    @omrsheet_parsed ||= {}
    # it is faster create new YAMLs by marshaling them instead of having
    # to parse them again.
    return Marshal.load(@omrsheet_parsed[omrsheet]) if @omrsheet_parsed[omrsheet]
    doc = YAML::load(File.read(omrsheet))
    doc.pages.each do |p|
      next if p.questions.nil?
      p.questions.each do |q|
        if q.save_as.empty?
        debug "db_column attribute for #{omrsheet} question #{q.db_column} contains only invalid characters or is empty. Only a-z, A-Z, 0-9 and hyphens are allowed, please include at least some in the db_column."
          exit 7
        end
        next if q.boxes.nil?
        q.boxes.each do |b|
          b.width  = b.width/SP_TO_PX*dpifix unless b.width.nil?
          b.height = b.height/SP_TO_PX*dpifix unless b.height.nil?
          b.x = b.x / SP_TO_PX*dpifix
          b.y = PAGE_HEIGHT*dpifix - (b.y / SP_TO_PX*dpifix)
        end
      end
    end
    @omrsheet_parsed[omrsheet] = Marshal.dump(doc)
    doc
  end
end
