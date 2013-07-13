# encoding: utf-8

class Term < ActiveRecord::Base
  has_many :forms, :inverse_of => :term
  has_many :courses, :inverse_of => :term
  has_many :course_profs, :through => :courses
  has_many :tutors, :through => :courses
  has_many :faculties, :through => :courses, :uniq => true
  validates_presence_of :title
  validates_presence_of :longtitle

  include FunkyTeXBits

  # Returns array of all terms that are currently active. I.e., a
  # more efficient way of Term.find(:all).find_all { |t| t.now? }.
  def self.currently_active
    d = Date.today
    find(:all, :conditions => ["firstday <= ? AND lastday >= ?", d, d])
  end

  def self.currently_active_forms
    Term.currently_active.map { |t| t.forms }.flatten
  end

  # returns the expected amount of sheets not yet processed for the
  # currently active terms. Also returns the weighted average return
  # quota as second parameter.
  def self.sheets_to_go
    # calculate the weighted average of the return quota.
    return_quota = 0
    sheets_done = 0
    sheets_to_go = 0
    Term.currently_active.each do |t|
      t.courses.includes(:course_profs).each do |c|
        if c.returned_sheets?
          return_quota += c.return_quota*c.returned_sheets
          sheets_done += c.returned_sheets
        else
          sheets_to_go += c.students
        end
      end
    end

    # fill in default value if there aren’t any returned sheets yet
    if return_quota == 0
      return_quota = 0.75
    else
      return_quota /= sheets_done.to_f
    end

    sheets_to_go *= return_quota
    return sheets_to_go, return_quota
  end

  # lists all barcodes associated with the current term
  def barcodes
    course_profs.map { |cp| cp.id }
  end

  # evaluate a faculty. If censor is set to true, will automatically
  # censor certain parts depending on the agreed-value for each lecturer
  def evaluate(faculty, censor = false)
    tables = forms.map { |f| f.db_table }

    # Let the database do the selection and sorting work. Also include
    # tutor and prof models since we are going to count them later on.
    # Since we need all barcodes, include course_prof as well.
    cs = courses.find_all_by_faculty_id(faculty, \
      :order => "TRIM(LOWER(title))", \
      :include => [:course_profs, :profs, :tutors])

    missing_censor = cs.select { |c| !c.enough_censored_parts_in_comments? }
    if missing_censor.size > 0
      puts "It appears that the following lectures have not enough"
      puts "censoring in their summaries / prof comments. You need to"
      puts "fix this first."
      missing_censor.each { |c| puts c }
      raise "Fix missing censoring first."
    end

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
    term_title = { :short => title, :long => longtitle }
    b << ERB.new(RT.load_tex("preface")).result(binding)

    puts "Evaluating #{cs.count} courses…"
    cs.each { |c| b << c.evaluate(nil, censor).to_s }

    b << RT.sample_sheets_and_footer(forms)
    return b
  end

  # is it currently this term?
  def now?
    (firstday <= Date.today && Date.today <= lastday)
  end

  # are we currently in the critical phase alias
  def critical?
    critical
  end

  # returns the lang code if Term has only one language for the given
  # faculty or faculty_id and false otherwise.
  def is_single_language?(faculty)
    id = faculty.is_a?(Faculty) ? faculty.id : faculty
    langs = courses.where(:faculty_id => id).pluck(:language).uniq
    langs.size == 1 ? langs.first.to_sym : false
  end

  def dir_friendly_title
    ActiveSupport::Inflector.transliterate(title.strip).gsub(/[^a-z0-9_-]/i, '_')
  end
end
