#!/usr/bin/env ruby

# boegen im aktuellen verzeichnis richtig drehen, ueberschreibt
# urspruengliche dateien haette gern two-pages-tifs ... 

# USAGE: bogendrehen.rb file.tif
require 'RMagick'
require 'ftools'

include Magick

def find_barcode_on_first(imagelist, tmp_filename)
  imagelist[0].write(tmp_filename)
  r = `bardecode #{tmp_filename}`
  if not r.empty?
    return r.strip.sub(/^.*\(/,'').sub(')]','').split(',').map{ |s|
      s.to_i } 
  else
    return nil
  end
end
f = ARGV[0]

pages = ImageList.new(f)

changed_smth = nil

tmp_filename = "/tmp/bgndrhn_#{f}_#{Time.now.to_i}.tif"

r = find_barcode_on_first(pages, tmp_filename)
  
if r.nil?
  r = find_barcode_on_first(pages.reverse!, tmp_filename)
  if r.nil?
    `mv #{f} bizarre`
    puts "bizarre #{f}"
    Process.exit
  end
  puts "switched #{f}"
  changed_smth = true
end

if r[0] < r[1]
  pages.map! { |i| i.rotate(180) }
  puts "flipped #{f}"
  changed_smth = true
end

File.delete(tmp_filename)

pages.write(f) unless changed_smth.nil?
