require 'enumerator'
require 'tmpdir'

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

def bold(text)
	"\e[1m#{text}\e[0m"
end

def word_wrap(txt, col = 80)
    txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n")
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
  Dir.chdir(tmp) do
    break unless pdf_crop_tex(pdffile)
    worked = true
    `mv -f cropped.pdf "#{pdffile}"`
  end
  `rm -rf #{tmp}`
  worked
end

# Generates a pdf file with the barcode in the specified location
def generate_barcode(barcode, path)
  path = File.expand_path(path)
  FileUtils.mkdir_p(File.join(Dir.tmpdir, "seee"))
  tmp = Dir.mktmpdir("seee/barcode-")
  Dir.chdir(tmp) do
    `barcode -b "#{barcode}" -g 80x30 -u mm -e EAN -n -o barcode.ps`
    `ps2pdf barcode.ps barcode.pdf`
    break unless pdf_crop_tex("barcode.pdf")
    `mv -f cropped.pdf "#{path}"`
  end
  `rm -rf #{tmp}`
end

# helper function, that generates a cropped version named "cropped.pdf"
# of the pdffile in the current working directory. Usually you want to
# call this like pdf_crop or generate_barcode
def pdf_crop_tex(pdffile)
  bboxes= `gs -sDEVICE=bbox -dBATCH -dNOPAUSE -c save pop -f '#{pdffile}' 2>&1 1>/dev/null`.scan(/%%BoundingBox:\s*((?:[0-9]+\s*){4})/m)
  return false if bboxes.nil? || bboxes.size <= 1
  File.open("cropped.tex", "w") do |h|
    h << "\\csname pdfmapfile\\endcsname{}\n"
    h << "\\def\\page #1 [#2 #3 #4 #5]{%\n"
    h << "  \\count0=#1\\relax\n"
    h << "  \\setbox0=\\hbox{%\n"
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
      # each page appears twice, so skip every 2nd entry
      next if i%2 != 0
      bbox = bbox[0].strip.split(/\s+/)
      bbox[1] = bbox[1].to_i - 9
      h << "\\page #{i/2 + 1} [#{bbox.join(" ")}]\n"
    end
    h << "\\csname @@end\\endcsname\n"
    h << "\\end\n"
  end
  `#{Seee::Config.application_paths[:pdftex]} -halt-on-error cropped.tex`
  if $?.exitstatus != 0
    puts "Could not crop \"#{File.basename(pdffile)}\". Try to remove spaces or {} chars in the path+filename if any. Specifiying a working *pdftex* command in the config might work as well."
    puts `cat cropped.log`
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
