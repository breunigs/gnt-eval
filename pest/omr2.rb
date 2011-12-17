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

require cdir + '/../lib/FunkyDBBits.rb'

require cdir + '/helper.misc.rb' # also load rmagick

require cdir + '/helper.boxtools.rb'
require cdir + '/helper.database.rb'
require cdir + '/helper.drawing.rb'
require cdir + '/helper.constants.rb'
require cdir + '/helper.image.rb'

require cdir + '/../lib/AbstractForm.rb'
require cdir + '/helper.AbstractFormExtended.rb'
require cdir + '/../lib/RandomUtils.rb'

# Profiler. Uncomment code at the end of this file, too.
#~ require 'ruby-prof'
#~ RubyProf.start


class PESTOmr < PESTDatabaseTools
  include PESTDrawingTools
  include PESTImageTools

  # Tries to locate a square box exactly that has been roughly located
  # using the position given by TeX and after applying offset+rotation.
  # Returns x, y coordinates that may be nil and also modifies the box
  # coordinates themselves (unless the box isn't found)
  def search_square_box(img_id, box)
    # TWEAK HERE
    if box.width.nil?
      box.width, box.height = 40, 40
      # TeX stores the box’s coordinates near its bottom right corner.
      # This translation is static and thus different to the one introduced
      # by imperfect scanning. Positive values move the box left/top.
      moveleft, movetop = 53, 41
    else
      # if the last box is a textbox, adjust some values so the textbox
      # can be checked. For now, only checked/unchecked is supported.
      moveleft, movetop = 1, 67
      box.height = 40
    end

    # Original position as given by TeX
    draw_transparent_box(img_id, box.tl, box.br, "yellow")
    # correct values to point to the box’s top left corner and print it
    box.x -= moveleft; box.y -= movetop
    draw_transparent_box(img_id, box.tl, box.br, "cyan", "", true)
    # still need to address scanning skew
    tl = correct(img_id, [box.x, box.y])
    box.x, box.y = tl.x, tl.y

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

    draw_text(img_id, [x-15,y+20], "black", box.choice) unless [x,y].any_nil?

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
        debug "Couldn't find box for page=#{img_id} box=#{box.choice}"+\
              " db_column=#{question.db_column}"
        debug "Assuming there is no box and no choice was made."
        debug
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
            when 0: 0 # well, no checkmarks either
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
  def process_whole_page(img_id, group)
    i = @ilist[img_id]
    # Crop margins to remove black bars that appear due to rotated sheets
    c = @corners[img_id]
    x = ((c[:tr].x + c[:br].x)/2.0 - (c[:tl].x + c[:bl].x)/2.0).to_i
    y = ((c[:bl].y + c[:br].y)/2.0 - (c[:tl].y + c[:tr].y)/2.0).to_i
    # safety margin so that the corners are not included
    s = 2*30*@dpifix
    c = i.crop(Magick::CenterGravity, x-s, y-s).trim(true)

    # region is too small, assume it is empty
    return 0 if c.rows*c.columns < 500*@dpifix

    c = c.resize(0.4)

    step = 20*@dpifix
    thres = 100

    # Find left border
    left = 0
    while left < c.columns
      break if black_pixels_img(c, left, 0, step, c.rows) > thres
      left += step
    end
    return 0 if left >= c.columns

    # Find right border
    right = c.columns
    while right > 0
      break if black_pixels_img(c, right-step, 0, step, c.rows) > thres
      right -= step
    end
    return 0 if right < 0

    # Find top border
    top = 0
    while top < c.rows
      break if black_pixels_img(c, 0, top, c.columns, step) > thres
      top += step
    end
    return 0 if top >= c.rows

    # Find bottom border
    bottom = c.rows
    while bottom > 0
      break if black_pixels_img(c, 0, bottom-step, c.columns, step) > thres
      bottom -= step
    end
    return 0 if bottom < 0

    c.crop!(left-50, top-50, right-left+2*50, bottom-top+2*50)
    c.trim!(true)

    # check again for size after cropping. Drop if too small.
    return 0 if c.rows*c.columns < 500*@dpifix

    filename = @path + "/" + File.basename(@currentFile, ".tif")
    filename << "_" + group.save_as + ".jpg"
    debug "  Saving Comment Image: " + filename if @verbose
    c.write filename

    return 1
  end

  # detects if a text box contains enough text and reports the result
  # (0 = no text, 1 = has text). It will automatically extract the
  # portion of the scanned sheet with the text and save it as .jpg.
  def process_text_box(img_id, question)
    # TWEAK HERE
    limit = 1000 * @dpifix
    # the x,y coordinate is made before the box, so we need to account
    # for the box border. It marks the top left corner.
    addtox, addtoy = 15, 15
    # the width,height are made inside the box, so we don’t have to
    # account for the box border. Note that width/height is actually a
    # coordinate until we make it relative below
    addtow, addtoh = 15, 1

    # init that no black pixels have been found so far
    bp = 0

    # only take first box into account, multi-rectangle comments are not
    # supported
    b = question.boxes.first
    # apply correction values and make width/height relative. Note that
    # TeX’s coordinates are from the lower left corner, but we use the
    # top left corner. This is usually corrected when loading the YAML
    # file, but since width/height are not supposed to be coordinates we
    # have to do it by hand. Grep this: WIDTH_HEIGHT_AS_COORDINATE
    b.x += addtox; b.y += addtoy; b.width += addtow - b.x
    b.height = PAGE_HEIGHT*@dpifix - b.height - b.y + addtoh
    # in a perfect scan, the coordinates now mark the inside of the box
    draw_dot(img_id, b.top_left, "red")
    draw_dot(img_id, b.top_right, "red")
    draw_dot(img_id, b.bottom_left, "red")
    draw_dot(img_id, b.bottom_right, "red")

    # split into smaller chunks, so we can skip the rest of the comment
    # box once enough black pixels have been found
    boxes = splitBoxes(b, 150, 100)

    boxes.each do |box|
      # correct skew
      tl = correct(img_id, box.tl)
      br = correct(img_id, box.br)
      # update box values
      box.x, box.y = tl.x, tl.y
      box.width, box.height =  br.x-tl.x, br.y-(tl.y)
      # search
      bp += black_pixels(img_id, box.x, box.y, box.width, box.height)
      color = bp > limit ? "green" : "red"
      draw_transparent_box(img_id, tl, br, color, bp, true)
      break if bp > limit
    end

    return 0 if bp <= limit

    # Save the comment as extra file if possible/required
    save_text_image(img_id, question.save_as, boxes)
    return 1
  end

  # Saves a given area (in form of a boxes array) for the current image.
  def save_text_image(img_id, save_as, boxes, use_page_width = true)
    return if save_as.nil? || save_as.empty?
    debug("    Saving Comment Image: #{save_as}", "save_image") if @verbose
    filename = @path + "/" + File.basename(@currentFile, ".tif")
    filename << "_" + save_as + ".jpg"
    x, y, w, h = calculateBounds(boxes)
    if use_page_width
      img = @ilist[img_id].crop(0, y, PAGE_WIDTH, h, true).minify
    else
      img = @ilist[img_id].crop(x, y, w, h, true).minify
    end
    # add text about where to find the original file
    @draw[999] = Magick::Draw.new
    @draw[999].pointsize = 9*@dpifix
    draw_solid_box(999, [0,0], [PAGE_WIDTH/2, 7], "white")
    draw_text(999, [1,7], "black", "Comment cut off? See #{File.expand_path(@currentFile, @path)} page #{img_id+1}")
    @draw[999].draw(img)
    # write out file
    img.write filename

    if @debug
      draw_text(img_id, [x,y], "green", "Saved as: #{filename}")
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
            g.value = process_whole_page(i, g)
          else
            debug "    Unsupported type: " + g.type.to_s
        end
      end
    end
    debug("  Recognized Image", "recog_img") if @verbose
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
    @doc = load_yaml_sheet(@omrsheet)
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
      img.write(dbgFlnm) { self.quality = 90 }
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
          vals << (q.value.include?(i+1) ? 1 : 0).to_s
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
    # don’t do anything in test mode because there is no database access
    # and we want to test all files anyway
    return files if @test_mode

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
  # processed form AND that are available in the loaded image
  def page_count
    parse_omr_sheet if @page_count.nil?
    [@page_count, @ilist.size].compact.min
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

        opts.on("-d", "--debug", "Specify if you want debug output as well.", "Will write a JPG file for each processed sheet to the working directory; marked with black percentage values, thresholds and selected fields.", "Be aware, that this makes processing about four times slower.", "Automatically activates debug database (may be overwritten by test mode)") { @debug = true }

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
