# encoding: utf-8

module ApplicationHelper
  # via http://edward.oconnor.cx/2007/08/tex-poshlet

  def tex_logo
    %(<span class="tex">T<sub>e</sub>X</span>).html_safe
  end

  def latex_logo
    %(<span class="latex">L<sup>a</sup>T<sub>e</sub>X</span>).html_safe
  end
end
