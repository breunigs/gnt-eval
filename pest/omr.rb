#!/usr/bin/ruby1.9

# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: OMR (Optical Mark Recognition)
#
# Parses a set of files or a given directory and saves the results for
# each image/sheet into the given directory. Results are the corrected
# x/y values for all elements given in the input-sheet (rotation, off-
# set) and the answers (choice, nochoice, failchoice attributes for each
# group/question). Outputs images for each fill out free text field if
# specified.
#
# Call omr.rb without arguments for list of possible/required arguments

require 'rubygems'
require 'RMagick'
require 'optparse'
require 'yaml'
require 'pp'

require 'helper.array.rb'
require 'helper.boxtools.rb'
require 'helper.constants.rb'
require 'helper.math.rb'

class PESTOmr
    # Finds the percentage of black/white pixels for the given rectangle
    # and image.
    def blackPercentage(x, y, width, height, img)
        black = blackPixels(x, y, width, height, img)
        all = (width*height).to_f
        return (black/all*100.0)
    end

    # Counts the black pixels in the given area and image.
    def blackPixels(x, y, width, height, img)
        black = 0
        begin
            rect = img.export_pixels(x, y, width, height, "G")
        rescue
            # This occurs when we specified invalid geometry: i.e. zero
            # width or height or reuqesting pixels outside the image.
            # Output some nice debugging data and just return 0.
            puts "\nx: " + x.to_s
            puts "y: " + y.to_s
            puts "w: " + width.to_s
            puts "h: " + height.to_s
            puts "g: " + @group['dbvalue'] if @group
            puts img.inspect
            puts @ilist.inspect
            return 0
        end
        rect.each { |x| black += 1 if x == 0 }
        black
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
        start_time = Time.now
        print @spaces + "  Correcting Rotation" if @verbose
        @rad = []
        @ilist.each do |img|
            topstart = findFirstPixelsFromLeft(95, 50,   250, 250, 9, img)
            botstart = findFirstPixelsFromLeft(95, 2650, 250, 250, 9, img)

            # The text on the bottom half is a little indented compared
            # to the upper one. The horizontal lines are not enough
            # "black enough" to be used for orientation, so we have to
            # go for the text and correct the offset here.
            botstart -= 5

            # Calculate angle in radians
            @rad << Math.atan((botstart - topstart).to_f/(2650 - 50 - 250).to_f)

            if @debug
                # Careful! This draws into the images before they are
                # completely recognized. If it intersects with a checkbox
                # the results will be wrong
                draw = Magick::Draw.new
                draw.font_weight = 100
                draw.pointsize = 20
                draw.fill("blue")
                draw.stroke("blue")
                draw.line(topstart,   50, topstart,   50+250)
                draw.line(botstart, 2650, botstart, 2650+250)
                draw.text(10, 35, (@rad.last*RAD2DEG).to_s)
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
        print @spaces + "  Determining Offset" if @verbose

        # FIXME: Move this somewhere else in order to support more than
        # two pages without changing code

        # X/Y values in the YAML files are relative to this corner
        leftcut = [145, 143]
        topcut = [65, 102]

        # This will contain the offset for each sheet
        @leftoff = [0,0]
        @topoff = [0,0]

        # Use different thresholds for each page to lessen the chance of
        # failing due to some black pixels
        leftThres = [9, 9]
        topThres = [20, 60]

        0.upto(@numPages-1) do |i|
            left   = findFirstPixelsFromLeft(95,   70, 500, 400, leftThres[i], @ilist[i])
            top    =  findFirstPixelsFromTop(1870, 50, 400, 500, topThres[i], @ilist[i])

            # Draw the lines where the threshold was found
            if @debug
                draw = Magick::Draw.new
                draw.font_weight = 100
                draw.pointsize = 20
                draw.fill("magenta")
                draw.stroke("magenta")
                draw.line(left, 70, left, 400)
                draw.line(1870, top, 2270, top)
                draw.text(10, 15, left.to_s + " x " + top.to_s)
            end

            # The offset detection is done at points that are affected
            # by rotation. We take this into account here.
            top +=  top - calcSkew(i, 1870 + 200, top)[1]
            left += left - calcSkew(i, left, 100 )[0]

            @leftoff[i] = left - leftcut[i]
            @topoff[i]  = top  -  topcut[i]

            # Draw the rotation-corrected lines
            if @debug
                draw.fill("magenta")
                draw.stroke("magenta")
                draw.line(left, 70, left, 400)
                draw.line(1870, top, 2270, top)
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
        return x.round, y.round
    end

    # This function encapsulates the process for determining if a set of
    # square boxes is checked and returns the appropriate answer.
    def typeSquareParse(imgid, group)
        checks = []
        first = true
        inner = SQUARE_SIZE - 2*SQUARE_STROKE

        group['boxes'].each do |box|
            x, y = calcSkew(imgid, box['x'], box['y'])

            # Find the pre-printed box
            mx = findFirstPixelsFromLeft(x, y, SQUARE_SEARCH[0]/2, SQUARE_SEARCH[1], 50, @ilist[imgid])


            # We didn't really find anything and got the maximum value
            # returned. Let's rather look a few pixels left or above for
            # the box
            maxCorr = 2
            while mx == x+ SQUARE_SEARCH[0]/2 && maxCorr > 0
                x -= SQUARE_STROKE*2
                mx = findFirstPixelsFromLeft(x, y, SQUARE_SEARCH[0]/2, SQUARE_SEARCH[1], 50, @ilist[imgid])
                maxCorr -= 1
            end

            my  = findFirstPixelsFromTop(mx, y, SQUARE_SEARCH[0], SQUARE_SEARCH[1]/2, 50, @ilist[imgid])
            # This is not a typo:        ^^
            # If we managed to find left already, we have better chances
            # of finding the correct top. If we found a wrong left we're
            # doomed anyway

            maxCorr = 3
            while my == y + SQUARE_SEARCH[1]/2 && maxCorr > 0
                y -= SQUARE_STROKE*2
                my  = findFirstPixelsFromTop(mx, y, SQUARE_SEARCH[0], SQUARE_SEARCH[1]/2, 50, @ilist[imgid])
                maxCorr -= 1
            end

            # Save corrected values to sheet so the FIX component doesn't
            # need to re-calculate this
            box['x'] = x
            box['y'] = y
            box['mx'] = mx
            box['my'] = my

            # First check for the inner pixels. If there are any, we al-
            # most absolutely have a checkmark
            bp = blackPercentage(mx + SQUARE_STROKE, my + SQUARE_STROKE, inner, inner, @ilist[imgid])

            # Save the raw value to the yaml
            box['bp'] = bp

            # Draw the rotation-correction-guidelines and the search
            # radius for each checkbox
            if @debug
                @draw.stroke("black")
                @draw.fill_opacity(1)
                @draw.text(x+SQUARE_SEARCH[0]+5, y+20, ((bp * 100).round.to_f / 100).to_s)

                @draw.line(x - 100, y, x + 100, y)
                @draw.line(x, y - 100, x, y + 200)

                if first
                    first = false
                    @draw.text(x - 50, y + 20, group['dbfield'])
                end

                @draw.stroke("blue")
                @draw.fill_opacity(0)
                @draw.rectangle(x, y, x + SQUARE_SEARCH[0], y + SQUARE_SEARCH[1])
            end
        end

        # At first, use very high thresholds so that question that are
        # clearly marked are not affected by small errors due to dirt or
        # imperfect scanning. If no checkmark is found, lower the thres-
        # hold each time. This makes it more prone to false-positives,
        # but at least keeps them to a minimum on questions that do not
        # need such a low limit.
        thresholds = [3.5, 1.5, 0.5]
        # This ensures that single boxes won't get checked because of
        # dirt. This might result in undetected checkmarks but no answer
        # is preferable over a wrong one.
        thresholds.pop if group['boxes'].size == 1

        threshold  = -1
        thresholds.each do |t|
            # Save for debugging uses
            threshold = t
            group['boxes'].each do |box|
                checks << box['choice'] if box['bp'] > t
            end
            break if checks.size >= 1
        end

        # Draws the red/green boxes for each answer
        if @debug
            group['boxes'].each do |box|
                color = box['bp'] > threshold ? "green" : "red"
                @draw.fill(color)
                @draw.fill_opacity(0.3)
                @draw.stroke(color)
                @draw.rectangle(box['mx'] + SQUARE_STROKE, box['my'] + SQUARE_STROKE, box['mx'] + SQUARE_STROKE + inner, box['my'] + SQUARE_STROKE + inner)
            end
        end

        case checks.length
            when 0 then return group['nochoice']
            when 1 then return checks[0]
            else        return group['failchoice']
        end
    end

    # This function tries to determine if a text field is filled out
    # If so and the "saveas" attribute is specified the comment will be
    # saved to the given filename.
    def typeTextParse(imgid, group)
        bp = 0
        limit = 1000
        boxes = []
        # Split up the text fields into many smaller boxes. Is is needed
        # for rotated sheets as the box would otherwise cover preprinted
        # areas and produce a false positive. If cut, large areas would
        # be missing and if would produce false negatives.
        # Splitting the boxes allows to circumvent this while still
        # being reasonable fast.
        group['boxes'].each { |box| boxes << splitBoxes(box, 150, 150) }
        boxes.flatten!
        boxes.each do |box|
            x, y = calcSkew(imgid, box['x'], box['y'])

            # We may need to shrink the detection rectangle on severe
            # rotations. Otherwise it would cover pre-printed text which
            # chould result in a false positive
            skewx, skewy = x - box['x'], y - box['y']

            # Save corrected values to sheet so the FIX component
            # doesn't need to re-calculate this
            box['x'] = x
            box['y'] = y

            bp += blackPixels(x, y, box['width'], box['height'], @ilist[imgid])

            if @debug
                color = bp > limit ? "green" : "red"
                @draw.fill(color)
                @draw.fill_opacity(0.3)
                @draw.stroke(color)
                @draw.rectangle(x, y, x + box['width'], y + box['height'])
                @draw.stroke("black")
                @draw.fill_opacity(1)
                @draw.text(x+5, y+20, bp.to_s)
            end

            break if bp > limit
        end
        group['blackPixels'] = bp

        # Save the comment as extra file if possible/required
        if group['saveas'] && bp > limit
            if @verbose
                print @spaces + "    Saving Comment Image: "
                puts group['saveas']
            end
            filename = @path + "/" + File.basename(@currentFile, ".tif")
            filename << group['saveas'] + ".jpg"
            x, y, w, h = calculateBounds(boxes, group)
            @ilist[imgid].crop(x, y, w, h).minify.write filename
        end
        
        # We're text-parsing, thus we can only have yes or no, but no
        # "fail" answer
        return bp > limit ? group['choice'] : group['nochoice']
    end

    # Looks at each group listed in the yaml file and calls the appro-
    # priate functions to parse it. This is determined by looking at the
    # "type" attribute as specified in the YAML file. Results are saved
    # directly into the loaded sheet.
    def recoImage
        start_time = Time.now
        puts @spaces + "  Recognizing Image" if @verbose

        max = Math::min(@ilist.length, @numPages) - 1

        0.upto(max) do |i|
            if @debug
                # Create @draw element the type*Parse functions can
                # access
                @draw = Magick::Draw.new
                @draw.font_weight = 100
                @draw.pointsize = 20
            end

            @doc['page'][i].each do |g|
                case g["type"]
                    when "square" then
                        # width, height and threshold are predefined for squares
                        g["value"] = typeSquareParse(i, g)
                    when "text" then
                        g['value'] = typeTextParse(i, g)
                    else
                        puts "Unsupported type: " + g['type'].to_s
                end
            end

            # Apply what the type*Parse functions drew
            @draw.draw(@ilist[i]) if @debug
        end

        puts @spaces + "    (took: " + (Time.now-start_time).to_s + " s)" if @verbose
    end

    # Does all of the overhead work required to be able to recognize an
    # image. More or less, it glues together all other functions and
    # saves the output to an YAML named like the input image.
    def parseFile(file)
        file = file.gsub(/\.yaml:?$/, ".tif")
        if !File.exists?(file) || File.zero?(file)
            puts @spaces + "WARNING: File not found: " + file
            return
        end

        @currentFile = file
        newfile = getNewFileName(file)

        start_time = Time.now
        print @spaces + "  Loading Image: " + file if @verbose

        # Load image and yaml sheet
        threadYaml = Thread.new do
            @doc = YAML::load(File.new(@omrsheet))
        end
        @ilist = Magick::ImageList.new(file)
        puts " (took: " + (Time.now-start_time).to_s + " s)" if @verbose

        # do the hard work
        findRotation
        findOffset

        threadYaml.join
        recoImage

        # Draw debugging image with thresholds, selected fields, etc.
        if @debug
            start_time = Time.now
            img = @ilist.append(false)
            dbgFlnm = newfile.gsub(/\.yaml$/, "_DEBUG.jpg")
            print @spaces + "  Saving Image: " + dbgFlnm if @verbose
            img.write dbgFlnm
            puts " (took: " + (Time.now-start_time).to_s + " s)" if @verbose
        end

        # Output generated data
        fout = File.open(newfile, "w")
        fout.puts YAML::dump(@doc)
        fout.close
    end

    # Helper function that determines where the parsed data should go
    def getNewFileName(file)
        return @path + "/" + File.basename(file, ".tif") + ".yaml"
    end

    # Checks for existing files and issues a warning if so. Returns a
    # list of non-exisitng files
    def checkForExistingFiles(files)
        puts @spaces + "Checking for existing files" if @verbose

        # Look for each file
        filesExist = false
        files.delete_if do |file|
            fn = getNewFileName(file)
            fileExist = File.exist?(fn) && File.size(fn) > 0
            puts @spaces + "  WARNING: File already exists: " + fn if fileExist
            fileExist
        end
        files
    end

    # Iterates a list of filenames and parses each. Checks for existing
    # files if told so and does all that "processing time" yadda yadda.
    def parseFilenames(files, overwrite)
        i = 0
        f = Float.induced_from(files.length)
        overall_time = Time.now
        skippedFiles = 0
        files.each do |file|
            # Processes the file and prints processing time
            file_time = Time.now
            i += 1
            print @spaces + "Processing File " + i.to_i.to_s + "/" + f.to_i.to_s
            puts  " (" + (i/f*100.0).to_i.to_s + "%)"
            parseFile(file)
            puts @spaces + "  Processing Time: " + (Time.now-file_time).to_s + " s" if @verbose
            puts ""

            # Calculates and prints time remaining
            rlFiles = Float.induced_from(i - skippedFiles)
            if rlFiles > 0
                timePerFile = (Time.now-overall_time)/rlFiles
                filesLeft = (files.length-rlFiles)
                puts @spaces + "Time remaining: " + ((timePerFile*filesLeft/60)+0.5).to_i.to_s + " m"
            end
        end

        # Print some nice stats
        puts ""
        puts ""
        puts ""
        puts ""
        t = Time.now-overall_time
        f = files.length - skippedFiles
        print @spaces + "Total Time: " + (t/60).to_s + " m "
        puts "(for " + f.to_s + " files)"
        puts @spaces + "(that's " + (t/f).to_s + " s per file)"
    end

    # Parses the given OMR sheet and extracts globally interesting data.
    # Currently this isn't too much, but this might change in the future.
    def parseOMRSheet
        doc = YAML::load(File.new(@omrsheet))
        @dbtable = doc['dbtable']
        @numPages = doc['page'].size
    end

    # Reads the commandline arguments and decides which routines to call
    def parseArguments
        # Define useful default values
        @omrsheet = nil
        @path     = nil
        overwrite = false
        @debug    = false
        @spaces   = "  "
        cores     = 1

        # Option Parser
        opt = OptionParser.new do |opts|
            opts.banner = "Usage: omr.rb --omrsheet omrsheet.yaml --path workingdir [options] [file1 file2 ...]"
            opts.separator("")
            opts.separator("REQUIRED ARGUMENTS:")
            opts.on("-s", "--omrsheet OMRSHEET", "Path to the OMR Sheet that should be used to parse the sheets") { |sheet| @omrsheet = sheet }

            opts.on("-p", "--path WORKINGDIR", "Path to the working directory where all the ouput will be saved.", "All paths are relative to this.") { |path| @path = path.chomp("/") }

            opts.separator("")
            opts.separator("OPTIONAL ARGUMENTS:")
            opts.on("-o", "--overwrite", "Specify if you want to output files in the working directory to be overwritten") { overwrite = true }

            opts.on("-c", "--cores CORES", Integer, "Number of cores to use (=processes to start)", "This spawns a new ruby process for each core, so if you want to stop processing you need to kill each process. If there are no other ruby instances running, type this command: killall ruby") { |c| cores = c }

            opts.on("-i", "--indent SPACES", Integer, "How much the messages should be indented.", "Will be automatically set for the additionally spawned processes when using multiple cores in oder to keep it readable for humans.") { |i| @spaces = " "*i }

            opts.on("-v", "--verbose", "Print more output (not recommended with cores > 1)") { @verbose = true }

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

        # All set? Ready, steady, parse!
        parseOMRSheet
        files = []

        # If no list of files is given, look at the given working
        # directory.
        if ARGV.empty?
            files = Dir.glob(@path + "/*.tif")
        else
            ARGV.each { |f| files << @path + "/" + f }
        end

        # Warn the user about existing files
        files = checkForExistingFiles(files) if !overwrite

        if cores > 1
            puts "Owning FormPro, " + cores.to_s + " sheets at a time"
            # The array is split unequally because the spawned processes
            # generally take longer than the main process. This tweak
            # ensures the processes run about equally long and therefore
            # produce the fastest output
            splitFiles = files.sqrtChunk(cores)
            files = splitFiles.shift
            path = " -p " + @path.gsub(/(?=\s)/, "\\")
            sheet = " -s " + @omrsheet.gsub(/(?=\s)/, "\\")
            d = @debug    ? " -d " : " "
            v = @verbose  ? " -v " : " "
            o = overwrite ? " -o " : " "
            corecount = 0
            splitFiles.each do |f|
                corecount += 1
                next if f.empty?
                list = ""
                f.each { |x| list << " " + File.basename(x).gsub(/(?=\s)/, "\\") }
                # This is the amount of spaces the output of newly
                # spawned instances are indented. Quite useful to keep
                # the console output readable.
                i = " -i " + (corecount*35).to_s
                system("ruby omr.rb " + sheet + path + i + v + d + o + list + " &")
            end
        end

        # Iterates over the given filenames and recognizes them
        parseFilenames(files, overwrite)
    end

    # Class Constructor
    def initialize
        parseArguments
    end
end

PESTOmr.new()
