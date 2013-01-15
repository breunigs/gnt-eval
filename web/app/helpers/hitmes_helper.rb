# encoding: utf-8

module HitmesHelper
  include FunkyTeXBits

  def text_to_list(text)
    return "" if text.blank?
    "\\begin{compactitem}\n\\item " + text.strip.gsub("\n", "\n\\item ") + "\n\\end{compactitem}"
  end
end
