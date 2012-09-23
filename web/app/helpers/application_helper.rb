# encoding: utf-8

module ApplicationHelper
  # via http://edward.oconnor.cx/2007/08/tex-poshlet

  def tex_logo
    %(<span class="tex">T<sub>e</sub>X</span>).html_safe
  end

  def latex_logo
    %(<span class="latex">L<sup>a</sup>T<sub>e</sub>X</span>).html_safe
  end

  # Returns the selected semester if given as param (and the ID is
  # valid). If it isn’t, returns all currently active semesters.
  def get_selected_semesters
    if params && params[:semester_id] && params[:semester_id].match(/^[0-9]+$/)
      s = Semester.find(params[:semester_id])
      return [s] if s
    end

    Semester.currently_active
  end
end
