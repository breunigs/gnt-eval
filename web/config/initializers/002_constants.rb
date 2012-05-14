# encoding: utf-8

APP_NAME="G'n'T Eval"


cdir = File.dirname(File.realdirpath(__FILE__))
GNT_ROOT = "#{cdir}/../../.." #unless defined?(GNT_ROOT)

# Define a global constant for easy access to ResultTools
RT = ResultTools.instance
