# encoding: utf-8

autoload :FileUtils, "fileutils"
autoload :PP, "pp"
autoload :YAML, "yaml"
autoload :RbConfig, "rbconfig"
autoload :WorkQueue, "work_queue"

# The file is in web/app/libs. However, it only contains a module; not
# a class. Because Rails won’t autoload modules, we require it here
# once manually, so the module becomes available.
require "FunkyTeXBits"
