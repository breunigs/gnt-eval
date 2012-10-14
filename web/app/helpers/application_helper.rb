# encoding: utf-8

module ApplicationHelper
  # via http://edward.oconnor.cx/2007/08/tex-poshlet

  def tex_logo
    %(<span class="tex">T<sub>e</sub>X</span>).html_safe
  end

  def latex_logo
    %(<span class="latex">L<sup>a</sup>T<sub>e</sub>X</span>).html_safe
  end

  # Returns the selected term if given as param (and the ID is
  # valid). If it isn’t, returns all currently active terms.
  def get_selected_terms
    if params && params[:term_id] && params[:term_id].match(/^[0-9]+$/)
      s = Term.find(params[:term_id])
      return [s] if s
    end

    Term.currently_active
  end
end
