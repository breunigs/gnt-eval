# -*- coding: utf-8 -*-
#require 'FunkyTeXBits.rb'

# A semester is a period of time, in which courses are held --
# typically a semester. A semester has many courses.
class Semester < ActiveRecord::Base
  has_many :courses
  has_many :forms
  validates_presence_of :title
  validates_presence_of :longtitle

  include FunkyTeXBits
  include FunkyDBBits

  # evaluate a faculty
  def evaluate(faculty)
    # Let the database do the selection and sorting work. Also include
    # tutor and prof models since we are going to count them later on.
    # Since we need all barcodes, include course_prof as well.
    puts "Finding associated courses…"
    #cs = courses.find_all{ |c| c.faculty_id == faculty.id }.sort{ |x,y| x.title <=> y.title }
    cs = courses.find_all_by_faculty_id(faculty, \
      :order => "TRIM(LOWER(title))", \
      :include => [:course_profs, :profs, :tutors])

    # now this IS a global variable, and we just set it for performance reasons. it is a
    # list of all barcodes corresponding to faculty and semester.
    $facultybarcodes = cs.map{ |c| c.barcodes }.flatten
    tables = cs.map { |c| c.form.db_table }

    puts "Counting all kinds of things…"
    course_count = cs.count
    sheet_count = rt.count(tables, {:barcode => $facultybarcodes})
    prof_count = cs.map { |c| c.profs }.flatten.uniq.count
    study_group_count = cs.inject(0) { |sum, c| sum + c.tutors.count }

    puts "Inserting preface and similar yadda yadda…"
    evalname = faculty.longname + ' ' + title

    b = ""
    # requires evalname
    b << ERB.new(rt.load_tex("preamble")).result(binding)
    b << rt.load_tex_definitions
    # requires the *_count variables
    b << ERB.new(rt.load_tex("header")).result(binding)

    facultylong = faculty.longname
    sem_title = { :short => title, :long => longtitle }
    b << ERB.new(rt.load_tex("preface")).result(binding)

    puts "Evaluating #{cs.count} courses…"
    cs.each { |c| b << c.evaluate.to_s }

    b << rt.sample_sheets_and_footer(forms)
    return b
  end

  # is it currently this semester?
  def now?
    (firstday <= Time.now.to_date && Time.now.to_date <= lastday)
  end

  # are we currently in the critical phase alias
  def critical?
    critical
  end

  def dirFriendlyName
    title.gsub(' ', '_').gsub('/', '_')
  end

  def dirfriendly_title
    dirFriendlyName
  end

  private
  # quick access to ResultTools.instance
  def rt
    ResultTools.instance
  end
end
