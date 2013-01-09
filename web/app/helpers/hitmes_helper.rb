# encoding: utf-8

module HitmesHelper
  include FunkyTeXBits

  def text_to_list(text)
    return "" if text.blank?
    "\\begin{itemize}\n\\item " + text.strip.gsub("\n", "\\item ") + "\\end{itemize}"
  end
end
