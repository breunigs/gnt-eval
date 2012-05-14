# encoding: utf-8

require "fileutils"

#~ require 'digest/md5' # FIXME: still required. DEPRECATED (?)

cdir = File.dirname(File.realdirpath(__FILE__))
#~ require(File.join(File.dirname(__FILE__),'../../config/initializers', 'seee_config.rb'))
require(File.join(cdir, '../../app/lib', 'result_tools.rb'))
require(File.join(cdir, '../../app/lib', 'AbstractForm.rb'))
require(File.join(cdir, '../../app/lib', 'FunkyTeXBits.rb'))
