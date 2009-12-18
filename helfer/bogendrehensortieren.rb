#!/usr/bin/env ruby

# boegen im aktuellen verzeichnis richtig drehen, ueberschreibt
# urspruengliche dateien haette gern two-pages-tifs ... 

# USAGE: bogendrehen.rb file.tif, writes X/file_bc.tif where X is formnumber
require 'RMagick'
require 'ftools'
require File.join(File.dirname(__FILE__), '../lib/ext_requirements.rb')

include Magick

def find_page(filename)
  r = `zbarimg --xml --set ean13.disable=1 #{filename} 2>/dev/null`
  if not r.empty?
    return r.strip.match(/^.*num='(\d)'.*/m)[1].to_i
  else
    return nil
  end
end

def find_barcode(filename)
  r = `zbarimg --set ean13.disable=1 #{filename} 2>/dev/null`
  if not r.empty?
    return r.strip.match(/^.*:(.*)$/)[1].to_i
  else
    return nil
  end
end

f = ARGV[0]
pages = ImageList.new(f)
changed_smth = nil

barcode = (find_barcode(f).to_f / 10).floor.to_i
page = find_page(f)

if barcode.nil? || page.nil? || (not CourseProf.exists?(barcode))
  puts "bizarre #{f}"
  File.makedirs("bizarre")
  `mv #{f} bizarre/`
  Process.exit
end

# is the barcode on the first page
if page != 0
  pages.reverse!
  puts "switched #{f}"
  changed_smth = true
end

# is the barcode on the upper half of the first page?
tmp_filename = "/tmp/bgndrhn_#{f}_#{Time.now.to_i}.tif"

pages[0].crop(0, 0, 2480, 1000).write(tmp_filename)

# the barcode is not at the top
if find_barcode(tmp_filename).nil?
  pages.map! { |i| i.rotate(180) }
  puts "flipped #{f}"
  changed_smth = true
end

File.delete(tmp_filename)

form = CourseProf.find(barcode).course.form.to_s
File.makedirs(form)
newfilename = (File.basename(f, '.tif') + '_' + barcode.to_s + '.tif')
pages.write(File.join(form, newfilename))

puts "Wrote #{form}/#{newfilename}"

