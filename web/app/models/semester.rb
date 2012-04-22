# -*- coding: utf-8 -*-

# A semester is a period of time, in which courses are held --
# typically a semester. A semester has many courses.
class Semester < ActiveRecord::Base
  has_many :courses
  has_many :course_profs, :through => :courses
  has_many :tutors, :through => :courses
  has_many :forms
  validates_presence_of :title
  validates_presence_of :longtitle

  include FunkyTeXBits

  # Returns array of all semesters that are currently active. I.e., a
  # more efficient way of Semester.find(:all).find_all { |s| s.now? }.
  def self.currently_active
    d = Date.today
    find(:all, :conditions => ["firstday <= ? AND lastday >= ?", d, d])
  end

  def self.currently_active_forms
    Semester.currently_active.map { |s| s.forms }.flatten
  end

  # lists all barcodes associated with the current semester
  def barcodes
    course_profs.map { |cp| cp.id }
  end

  # evaluate a faculty
  def evaluate(faculty)
    tables = forms.map { |f| f.db_table }

    # Let the database do the selection and sorting work. Also include
    # tutor and prof models since we are going to count them later on.
    # Since we need all barcodes, include course_prof as well.
    cs = courses.find_all_by_faculty_id(faculty, \
      :order => "TRIM(LOWER(title))", \
      :include => [:course_profs, :profs, :tutors])

    course_count = cs.count
    sheet_count = RT.count(tables, {:barcode => faculty.barcodes })
    prof_count = cs.map { |c| c.profs }.flatten.uniq.count
    study_group_count = cs.inject(0) { |sum, c| sum + c.tutors.count }

    evalname = faculty.longname + ' ' + title

    b = ""
    # requires evalname
    b << ERB.new(RT.load_tex("preamble")).result(binding)
    b << RT.load_tex_definitions
    # requires the *_count variables
    b << ERB.new(RT.load_tex("header")).result(binding)

    facultylong = faculty.longname
    sem_title = { :short => title, :long => longtitle }
    b << ERB.new(RT.load_tex("preface")).result(binding)

    puts "Evaluating #{cs.count} courses…"
    cs.each { |c| b << c.evaluate.to_s }

    b << RT.sample_sheets_and_footer(forms)
    return b
  end

  # is it currently this semester?
  def now?
    (firstday <= Date.today && Date.today <= lastday)
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
end
