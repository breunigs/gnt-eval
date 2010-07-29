require 'pp'
require 'stringio'

class Form < ActiveRecord::Base
  belongs_to :semester

  def abstract_form
    YAML::load(content)
  end
  def pretty_abstract_form
    orig = $stdout
    sio = StringIO.new
    $stdout = sio
    pp abstract_form
    $stdout = orig

    # aber bitte ohne die ids
    sio.string.gsub(/0x[^\s]*/,'')
  end
end
