#!/usr/bin/env ruby

# bogen richtig drehen, ueberschreibt urspruengliche dateien
# haette gern two-pages-tifs ...
# USAGE: bogendrehen.rb file1.tif file2.tif ...

require 'RMagick'
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

ARGV.each do |filename|
  pages = ImageList.new(filename)
  
  changed_smth = nil

  tmp_filename = '.tmp.tif'
  r = find_barcode_on_first(pages, tmp_filename)
  
  if r.nil?
    r = find_barcode_on_first(pages.reverse!, tmp_filename)
    puts "switched #{filename}"
    changed_smth = true
  end

  if r[0] < r[1]
    pages.map! { |i| i.rotate(180) }
    puts "flipped #{filename}"
    changed_smth = true
  end
  
  pages.write(filename) unless changed_smth.nil?

end
