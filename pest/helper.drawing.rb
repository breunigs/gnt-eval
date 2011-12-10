# extends the PESTOmr with some drawing related tools. This subclass
# is not intended to work alone, but rather supply useful functions
# that ought be used from within the main class. Expects there's a valid
# @draw array whose elements contain a Magick::Draw class for each page/
# image_id that should be drawn to.

module PESTDrawingTools
  def create_drawable(img_id)
    @draw[img_id] = Magick::Draw.new
    @draw[img_id].font_weight = 100
    #~ @draw[img_id].font_family('Helvetica')
    @draw[img_id].pointsize = 20*@dpifix
  end

  def draw_boilerplate(img_id, pwd, sheet, file)
    text1 = "Blue: Search areas\ndark green lines: rotation visualization\ncheckboxes:\n  yellow = orig pos; cyan = TeX correction\nscanning skew correction: not drawn\n  green = checked; orange = empty; red = overfull; strange green = barely checked  (box marks searched area, number is black%)\ntext boxes: values are black pixels so far; red = not enough yet; green = now enough; large green area = exported to file\ntext pages: no debug prints"
    text2 = "WDir: #{pwd}\nSheet: #{sheet}\nFile: #{file}"
    draw_text(img_id, [500, 40], "black", text1)
    draw_text(img_id, [1000, 40], "red", text2)
  end

  # draws the text at the given coord, optionally centering it
  def draw_text(img_id, coord, color, text, center = false)
    return if !@debug or coord.any_nil? or text.nil? or text.to_s.empty?
    @draw[img_id].stroke('none')
    @draw[img_id].fill(color)
    @draw[img_id].fill_opacity(1)
    if center
      m = @draw[img_id].get_type_metrics(text.to_s)
      @draw[img_id].text(coord.x-m.width/2.0, coord.y+m.height/2.0, text.to_s)
    else
      @draw[img_id].text(coord.x, coord.y, text.to_s)
    end
  end

  # draws a transparent rectangle for the area and highlights one side
  # of the border, depending on search direction. Also inserts an arrow
  # automatically to hint in which direction was being searched.
  def draw_search_box(img_id, tl, br, color, dir, with_text)
    return if !@debug or tl.any_nil? or br.any_nil?
    t = { :right => "> #{br.x}", :left => "< #{tl.x}",
	  :up => "^  #{tl.y}", :down => "v #{br.y}" }
    draw_transparent_box(img_id, tl, br, color, with_text ? t[dir] : "")
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

    xmid = tl.x + (br.x - tl.x)/2.0
    ymid = tl.y + (br.y - tl.y)/2.0
    draw_text(img_id, [xmid, ymid], color, text, true)
  end

  # draws a colored solid box for the given coordinates to the
  # image at @ilist[img_id].
  def draw_solid_box(img_id, tl, br, color)
    return if !@debug or tl.any_nil? or br.any_nil?
    @draw[img_id].fill(color)
    @draw[img_id].stroke(color)
    @draw[img_id].fill_opacity(1)
    @draw[img_id].stroke_opacity(1)
    @draw[img_id].rectangle(tl.x, tl.y, br.x, br.y)
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
end
