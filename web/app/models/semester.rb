# -*- coding: utf-8 -*-
#require 'FunkyTeXBits.rb'

class Semester < ActiveRecord::Base
  has_many :courses
  validates_presence_of :title
  
  include FunkyTeXBits
  include FunkyDBBits
  
  def evaluate(faculty, dbh)
    b = ''

    cs = courses.find_all{ |c| c.faculty == faculty }    

    # FunkyDBBits setup
    @dbh = dbh
    @db_table = cs.map { |c| c.form.to_form.db_table }.uniq

    evalname = ['Mathematik', 'Physik'][faculty] + ' ' + title
    anzahl_boegen = count_forms({ 'eval' => evalname })
    
    b << TeXKopf(evalname, cs.count, cs.inject(0) { |sum, c| sum +
                   c.profs.count }, cs.inject(0) { |sum, c| sum +
                   c.tutors.count }, anzahl_boegen)

    cs.each do |c|
      b << c.evaluate(dbh)
    end
    
    b << TeXFuss()
    
    return b
  end
  
  def eval_against_form!(faculty, form, dbh)
    puts eval_against_form(faculty, form, dbh)
  end
end
