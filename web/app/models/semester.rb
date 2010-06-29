# -*- coding: utf-8 -*-
#require 'FunkyTeXBits.rb'

# A semester is a period of time, in which courses are held --
# typically a semester. A semester has many courses.
class Semester < ActiveRecord::Base
  has_many :courses
  validates_presence_of :title

  include FunkyTeXBits
  include FunkyDBBits

  def evaluate(faculty, dbh)
    b = ''

    cs = courses.find_all{ |c| c.faculty == faculty }.sort{ |x,y| x.title <=> y.title }
    
    # now this IS a global variable, and we just set it for performance reasons. it is a
    # list of all barcodes corresponding to faculty and semester.
    $facultybarcodes = cs.map{ |c| c.course_profs.map { |cp| cp.barcode.to_i }}.flatten
    
    # FunkyDBBits setup
    @dbh = dbh
    @db_table = cs.map { |c| c.form.to_form.db_table }.uniq

    evalname = faculty.longname + ' ' + title
    anzahl_boegen = count_forms({})

    b << TeXKopf(evalname, cs.count, cs.inject(0) { |sum, c| sum +
                   c.profs.count }, cs.inject(0) { |sum, c| sum +
                   c.tutors.count }, anzahl_boegen)
    b << TeXVorwort(faculty.longname, title)

    cs.each do |c|
      b << c.evaluate(dbh)
    end

    b << TeXFuss()

    return b
  end

  # is it currently this semester?
  def now?
    (firstday <= Time.now.to_date && Time.now.to_date <= lastday)
  end

  def dirFriendlyName
    title.gsub(' ', '_').gsub('/', '_')
  end
  
  def dirfriendly_title
    dirFriendlyName
  end

  def eval_against_form!(faculty, form, dbh)
    puts eval_against_form(faculty, form, dbh)
  end
end
