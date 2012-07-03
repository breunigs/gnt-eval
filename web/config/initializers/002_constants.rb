# encoding: utf-8

#~ # Detect sources from where this file is included in case it’s loaded
#~ # more than once.
#~ begin
  #~ require "pp"
  #~ raise
#~ rescue Exception => e
  #~ pp e.backtrace
#~ end

APP_NAME="G'n'T Eval"


cdir = File.dirname(File.realdirpath(__FILE__))
GNT_ROOT = "#{cdir}/../../.." #unless defined?(GNT_ROOT)

# Define a global constant for easy access to ResultTools
RT = ResultTools.instance
