# -*- coding: utf-8 -*-
#require 'FunkyTeXBits.rb'

class Semester < ActiveRecord::Base
  has_many :courses
  validates_presence_of :title
  
  include FunkyTeXBits
  
  def eval_against_form(faculty, form, dbh)
    b = ''
    cs = courses.find_all{ |c| c.faculty == faculty }    
    evalname = ['Mathematik', 'Physik'][faculty] + ' ' + title
    anzahl_boegen = 0
    
    b << TeXKopf(evalname, cs.count, cs.inject(0) { |sum, c| sum +
                   c.profs.count }, cs.inject(0) { |sum, c| sum +
                   c.tutors.count }, anzahl_boegen)

    cs.each do |c|
      b << c.eval_against_form(form, dbh)
    end
    
    b << TeXFuss()
    
    return b
  end
  
  def eval_against_form!(faculty, form, dbh)
    puts eval_against_form(faculty, form, dbh)
  end
end
