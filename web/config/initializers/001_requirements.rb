# encoding: utf-8

require "fileutils"
require "pp"


cdir = File.dirname(File.realdirpath(__FILE__))
require(File.join(cdir, '../../app/lib', 'result_tools.rb'))
require(File.join(cdir, '../../app/lib', 'AbstractForm.rb'))
require(File.join(cdir, '../../app/lib', 'FunkyTeXBits.rb'))
