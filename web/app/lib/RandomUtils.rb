# -*- coding: utf-8 -*-
require 'enumerator'
require 'tmpdir'
require 'rubygems'
require 'work_queue'

class String
  # keeps only characters that may be used in a table name or column for
  # SQL querys. Adds some hacks to allow for COUNT(*) and DISTINCT blub.
  def keep_valid_db_chars
    new = self.scan(/[()*.0-9a-z_-]/i).join.gsub("DISTINCT", "DISTINCT ")
    if new != self
      puts "WARNING: String contained illegal characters for SQL queries."
      puts "         Original string: #{self}"
      puts "         Cleaned  string: #{new}"
    end
    new
  end
end

class Symbol
  # The same function as for strings.
  def keep_valid_db_chars
    self.to_s.keep_valid_db_chars.to_sym
  end
end

class String
  # wraps text after a maximum of X cols. 72 is the default for mails,
  # so don’t change it here.
  def word_wrap(col = 72)
    self.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3")
  end

  def bold
    "\e[1m#{self}\e[0m"
  end
end

# once the barcode has been recognized the images are stored in the
# format oldname_barcode.tif. This way barcode detection and OMR can
# be split up. This function reads the barcode from the filename.
def find_barcode_from_path(path)
  bc = path.to_s.match(/^.*\/([0-9]+)_[^\/]*$/)
  return nil if bc.nil?
  bc[1]
end

# http://snippets.dzone.com/posts/show/3486
class Array
  def chunk(pieces)
    q, r = length.divmod(pieces)
    (0..pieces).map { |i| i * q + [r, i].min }.enum_cons(2).map { |a, b| slice(a...b) }
  end
end

def number_of_processors
  `cat /proc/cpuinfo | grep processor | wc -l`.strip.to_i
end

# Prints the current progress to the console without advancing one line
# val: currently processed item
# max: amount of items to process
def print_progress(val, max)
      percentage = (val.to_f/max.to_f*100.0).to_i.to_s.rjust(3)
      current = val.to_s.rjust(max.to_s.size)
      print "\r#{percentage}% (#{current}/#{max})"
      STDOUT.flush
end

# crops the given pdf file in place. If cropping fails for some reason,
# the original file is not overwritten
def pdf_crop(pdffile)
  tmp = Dir.mktmpdir("seee/pdfcrop-")
  worked = false
  pdfdir = `pwd`.chomp
  Dir.chdir(tmp) do
    break unless pdf_crop_tex(pdffile, pdfdir)
    worked = true
    `mv -f cropped.pdf "#{pdffile}"`
  end
  `rm -rf #{tmp}`
  worked
end

# Generates a pdf file with the barcode in the specified location
def generate_barcode(barcode, path)
  # skip if the barcode already exists
  path = File.expand_path(path)
  return true if File.exists?(path)
  # ensure the main temp directory exists
  tmp = File.join(Dir.tmpdir, "seee-tmp")
  FileUtils.mkdir_p(tmp, {:mode => 0777})
  # create own subfolder for each barcode
  tmp = Dir.mktmpdir("barcode-", tmp)
  # Can't change into the tmp directory here because Dir.chdir cannot
  # be nested and we might need this feature elsewhere.
  `barcode -b "#{barcode}" -g 80x30 -u mm -e EAN -n -o #{tmp}/barcode.ps`
  `ps2pdf #{tmp}/barcode.ps #{tmp}/barcode.pdf`
  return false unless pdf_crop_tex("barcode.pdf", tmp)
  `mv -f #{tmp}/cropped.pdf "#{path}"`
  `rm -rf #{tmp}`
  true
end

# helper function, that generates a cropped version named "cropped.pdf"
# of the pdffile in the current working directory. Usually you want to
# call this like pdf_crop or generate_barcode
def pdf_crop_tex(pdffile, dir = "./")
  dir += "/" unless dir.end_with?"/"

  gs_out = `gs -sDEVICE=bbox -dBATCH -dNOPAUSE -c save pop -f '#{dir}#{pdffile}' 2>&1 1>/dev/null`
  bboxes = gs_out.scan(/%%BoundingBox:\s*((?:[0-9]+\s*){4})/m)
  if bboxes.nil? || bboxes.empty?
    puts "Could not run ghostscript or couldn't find suitable bounding boxes in given file"
    return false
  end
  twice_print_bug = gs_out.split("\n")[1].start_with?("%%Bounding")

  File.open("#{dir}cropped.tex", "w") do |h|
    h << "\\csname pdfmapfile\\endcsname{}\n"
    h << "\\def\\page #1 [#2 #3 #4 #5]{%\n"
    h << "  \\count0=#1\\relax\n"
    h << "  \\setbox0=\\hbox{%\n"
    # relative path is okay here, because we will cd into the right
    # directory before calling TeX
    h << "    \\pdfximage page #1{#{pdffile}}%\n"
    h << "    \\pdfrefximage\\pdflastximage\n"
    h << "  }%\n"
    h << "  \\pdfhorigin=-#2bp\\relax\n"
    h << "  \\pdfvorigin=#3bp\\relax\n"
    h << "  \\pdfpagewidth=#4bp\\relax\n"
    h << "  \\advance\\pdfpagewidth by -#2bp\\relax\n"
    h << "  \\pdfpageheight=#5bp\\relax\n"
    h << "  \\advance\\pdfpageheight by -#3bp\\relax\n"
    h << "  \\ht0=\\pdfpageheight\n"
    h << "  \\shipout\\box0\\relax\n"
    h << "}\n"
    bboxes.each_with_index do |bbox,i|
      # for some gs versions each page appears twice, so skip every
      # 2nd entry if that is the case
      next if twice_print_bug && i%2 != 0
      bbox = bbox[0].strip.split(/\s+/)
      bbox[1] = bbox[1].to_i - 9
      h << "\\page #{i/2 + 1} [#{bbox.join(" ")}]\n"
    end
    h << "\\csname @@end\\endcsname\n"
    h << "\\end\n"
  end
  `cd "#{dir}" && #{Seee::Config.application_paths[:pdftex]} -halt-on-error cropped.tex`
  if $?.exitstatus != 0
    puts "Could not crop \"#{File.basename(pdffile)}\". Try to remove spaces or {} chars in the path+filename if any. Specifiying a working *pdftex* command in the config might work as well."
    puts `cat #{dir}cropped.log`
    return false
  end
  true
end

def temp_dir
  tmp = Seee::Config.file_paths[:cache_tmp_dir]
  require 'ftools'
  File.makedirs(tmp)
  `chmod 0777 -R #{tmp}`
  tmp
end

# creates or returns a global work queue. Executes (amount of cpus)
# threads simultaneously. Usage:
# work_queue.enqueue_b { puts "Hello from the WorkQueue" }
# work_queue.join
def work_queue
  $global_work_queue ||= WorkQueue.new(number_of_processors)
  $global_work_queue
end
