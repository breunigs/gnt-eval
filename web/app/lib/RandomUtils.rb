# -*- coding: utf-8 -*-
require 'enumerator'
require 'tmpdir'
require 'rubygems'
require 'work_queue'

require File.join(File.dirname(__FILE__), "seee_config.rb")
require File.join(File.dirname(__FILE__), "tex_tools.rb")

Scc = Seee::Config.commands unless defined?(Scc)

module Enumerable
  # finds duplicates in an Enum. As posted by user bshow on
  # http://snippets.dzone.com/posts/show/3838
  def get_duplicates
    inject({}) {|h,v| h[v]=h[v].to_i+1; h}.reject{|k,v| v==1}.keys
  end
end

class Hash
  # abbreviation for self.fetch(key, 0)
  def foz(k)
    self.fetch(k, 0)
  end
end

class Symbol
  # DEPRECATED
  # The same function as for strings.
  def keep_valid_db_chars
    self.to_s.keep_valid_db_chars.to_sym
  end
end

class String
  # removes all HTML Tags from text
  def strip_html
    self.gsub(/<\/?[^>]*>/, "")
  end

  # wraps text after a maximum of X cols. 72 is the default for mails,
  # so don’t change it here.
  def word_wrap(col = 72)
    self.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3")
  end

  def bold
    "\e[1m#{self}\e[0m"
  end

  # Actually only useful for arrays. This is a convenience feature so
  # that no checking for Array/String has to be made.
  def find_common_start
    self
  end

  # Make downcase support German umlauts
  def downcase
    self.tr 'A-ZÄÖÜ', 'a-zäöü'
  end

  # Capitalizes the first letter of the string and leaves all other
  # chars alone.
  def capitalize_first
    self.slice(0,1).capitalize + self.slice(1..-1)
  end
end

# Tries to simplify paths to make them more user-readable. The path will
# be normalized and have its part pointing to the projects main dir
# removed, if the path is a subfolder (or file within the project).
def simplify_path(path)
  rr = File.expand_path(File.join(RAILS_ROOT, "..")) + "/"
  File.expand_path(path).gsub(/^#{rr}/, "")
end

# Finds the barcode of a given image file by looking at the image.
# Automatically rotates and orders the pages if  a barcode is found.
def find_barcode(filename)
  zbar = Seee::Config.application_paths[:zbar]
  unless File.exist?(zbar)
    puts "Couldn’t find a suitable zbarimg executable. This is likely due to your platform (= #{`uname -m`.strip}) not being supported by default. You can resolve this by running “rake magick:buildZBar”."
    exit 1
  end
  zbar = Seee::Config.commands[:zbar]

  r = `#{zbar} "#{filename}"`
  if not r.empty?
    return r.strip.match(/^([0-9]+)/)[1].to_i
  else
    return nil
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

  # converts the values in the array to their value in % with 100% being
  # the sum of the array. If no argument is given, rounds to natural
  # numbers. Does not check if the contents of the array make sense,
  # e.g. negative values will not be detected.
  def to_percentage(round_to = 0)
    t = self.total.to_f
    rf = 10**round_to
    self.map { |x| ((x.to_f/t)*rf*100).round/rf }
  end

  # don’t name this "sum", it is blocked by Rails with a different
  # implementation that requires an argument.
  def total
    inject( nil ) { |sum,x| sum ? sum+x : x }
  end

  # returns the substring starting from the first letter that all
  # entries have in common.
  def find_common_start
    return "" if self.length <= 0
    (0...self.first.length).each do |k|
        char = self.first[k]
        return self.first.slice(0, k) if self.any? { |s| char != s[k] }
    end
    a.first
  end

  # calls String#strip_common_tex for each argument
  def strip_common_tex
    self.map { |x| x.to_s.strip_common_tex }
  end
end

def number_of_processors
  `cat /proc/cpuinfo | grep processor | wc -l`.strip.to_i
end

# Prints the current progress to the console without advancing one line
# val: currently processed item
# max: amount of items to process
# title: print name of just processed item
def print_progress(val, max, title = "")
  percentage = (val.to_f/max.to_f*100.0).to_i.to_s.rjust(3)
  current = val.to_s.rjust(max.to_s.size)
  print "\r#{percentage}% (#{current}/#{max})\t#{title[0..49].ljust(50)}"
  STDOUT.flush
end

# prints a headline surrounded by = into stdout
def print_head(text)
  puts "="*text.size
  puts text
  puts "="*text.size
end

# Generates a pdf file with the barcode in the specified location. Won’t
# regenerate the barcode, if a file in the target location exists.
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

# Creates form PDF file for given and CourseProf
def make_pdf_for(cp, dirname)
  # first: the barcode
  bc_path = File.join(dirname, "barcode#{cp.barcode}.pdf")
  if !generate_barcode(cp.barcode, bc_path)
    raise "could not generate barcode #{cp.barcode} in #{dirname}"
  end

  # second: the form
  filename = File.join(dirname, cp.get_filename)
  File.open(filename + '.tex', 'w') do |h|
    h << cp.course.form.abstract_form.to_tex(
      cp.course.language,
      cp.course.title,
      cp.prof.firstname,
      cp.prof.lastname,
      cp.prof.gender,
      cp.course.tutors.sort{ |a,b| a.id <=> b.id }.map{ |t| t.abbr_name },
      cp.semester.title,
      cp.barcode)
  end
  puts "Wrote #{filename}.tex"

  # generate PDF
  tex_to_pdf("#{filename}.tex", true)

  # it may be useful for debugging to have a YAML for each course.
  # however, it is not needed by gnt-eval itself, so remove it immediately
  # before it causes any confusion.
  `rm "#{filename}.posout"`
  #`./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
end

# crops the given pdf file in place. If cropping fails for some reason,
# the original file is not overwritten
def pdf_crop(pdffile)
  tmp = Dir.mktmpdir("seee/pdfcrop-")
  worked = false
  crop_err = nil
  Dir.chdir(tmp) do
    crop_stat, crop_err = pdf_crop_tex(pdffile, "", true)
    break unless crop_stat
    worked = true
    `mv -f cropped.pdf "#{pdffile}"`
  end
  `rm -rf #{tmp}`
  return worked, crop_err
end

# helper function, that generates a cropped version named "cropped.pdf"
# of the pdffile in the current working directory. Usually you want to
# call this like pdf_crop or generate_barcode
def pdf_crop_tex(pdffile, dir = "./", give_error = false)
  dir += "/" unless dir.end_with?"/"
  dir = "" if pdffile.start_with?"/"

  gs_out = `gs -sDEVICE=bbox -dBATCH -dNOPAUSE -c save pop -f '#{dir}#{pdffile}' 2>&1 1>/dev/null`
  bboxes = gs_out.scan(/%%BoundingBox:\s*((?:[0-9]+\s*){4})/m)
  if bboxes.nil? || bboxes.empty?
    puts "Could not run ghostscript or couldn't find suitable bounding boxes in given file"
    return false if !give_error
    return false, `gs -sDEVICE=bbox -dBATCH -dNOPAUSE -c save pop -f '#{dir}#{pdffile}'`
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
    page = 1
    bboxes.each_with_index do |bbox,i|
      # for some gs versions each page appears twice, so skip every
      # 2nd entry if that is the case
      next if twice_print_bug && i%2 != 0
      bbox = bbox[0].strip.split(/\s+/)
      bbox[1] = bbox[1].to_i - 9
      h << "\\page #{page} [#{bbox.join(" ")}]\n"
      page += 1
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
  return true
end

# Returns path to global cache/temporary directory. Ensures it is
# writable by everyone. If a subdir is given, will create and return
# that path.
def temp_dir(subdir = "")
  tmp = File.join(Seee::Config.file_paths[:cache_tmp_dir], subdir)
  require 'ftools'
  File.makedirs(tmp)
  `chmod 0777 -R '#{tmp.gsub("'","\\'")}'  2> /dev/null`
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


# reads user input and validates it. Returns an array if valid was an
# array and all items in the returned array are elements of valid. If
# valid is a regular expression a string is returned iff it matches
# the expression. Please note that all array values are converted to
# strings and entries will be seperated by space.
def get_user_input(valid)
  valid = valid.collect { |x| x.to_s } if valid.is_a? Array
  while true
    print "> "
    data = STDIN.gets.chomp
    if valid.is_a? Array
      data = data.strip.split(/\s+/)
      return data if data.all? { |x| valid.include?(x) }
      puts
      puts "Sorry, your input isn't valid. All entries must be in the following list."
      puts "Seperate entries by spaces if you want multiple values."
      puts valid.join(" ")
    else # regex
      return data if data =~ valid
      puts
      puts "Sorry, your input isn't valid. It must match this regular expression: #{valid}"
    end
    puts
    puts
  end
end

# tries to get user input that validates (compare with get_user_input)
# if the given "fake" value not nil. If it is, a input line with these
# parameters is printed in order to fake the user input. Note that the
# fake data is checked and the user will be asked if it appears to be
# wrong.
def get_or_fake_user_input(valid, fake)
  valid = valid.collect { |x| x.to_s } if valid.is_a? Array
  return get_user_input(valid) unless fake
  if valid.is_a? Array
    return get_user_input(valid) unless (fake.is_a?(Array) && fake.all? { |x| valid.include?(x) }) || valid.include?(fake)
  else
    return get_user_input(valid) unless fake =~ valid
  end
  puts "> #{fake.is_a?(Array) ? fake.join(" ") : fake}"
  fake
end

# Creates howtos for all available languages in the given directory, iff
# they do not exist already. If no specific path is given, will assume
# the forms are in the default path (usually tmp/forms)
def create_howtos(saveto, form_path = nil)
  FileUtils.mkdir_p(saveto)
  form_path ||= Seee::Config.file_paths[:forms_howto_dir]
  form_path = File.expand_path(form_path).escape_for_tex

  Dir.glob(GNT_ROOT + "/doc/howto_*.tex").each do |f|
    file = File.join(saveto, File.basename(f))
    # skip if the PDF file already exists
    next if File.exist?(file.gsub(/\.tex$/, ".pdf"))
    work_queue.enqueue_b do
      data = File.read(f).gsub(/§§§/, form_path)
      File.open(file, "w") { |x| x.write data }
      tex_to_pdf(file)
      File.delete(file)
    end
  end
  work_queue.join
end
