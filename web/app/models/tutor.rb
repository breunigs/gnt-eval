# encoding: utf-8

# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course, :inverse_of => :tutors
  has_many :pics, :inverse_of => :tutor
  has_one :form, :through => :course
  has_one :faculty, :through => :course
  has_one :term, :through => :course
  has_many :profs, :through => :course

  validates_presence_of :abbr_name
  validates_uniqueness_of :abbr_name, :scope => :course_id, \
    :message => "Tutor already exists for this course."

  enum_attr :censor, %w(^unknown none own_comments own_comments_and_stats), :init => :unknown, :nil => false

  include FunkyTeXBits

  # returns if the tutor is critical. This is the case when either the
  # parent course is critical or if the course has returned sheets
  def critical?
    course.critical? || course.returned_sheets > 0
  end

  def may_show_stats?
    !censor_stats?
  end

  def censor_stats?
    tutor_ok = censor_unknown? || censor_none? || own_comments?
    prof_ok = profs.none? { |p| p.censor_everything? }
    may_show = tutor_ok && prof_ok
    #~ reason = may_show ? :none : (tutor_ok ? :prof : :tutor)
    return !may_show#, reason
  end

  def may_show_comments?
    !censor_comments?
  end

  # returns true if comments should be censored. The 2nd argument
  # contains either :none, :prof or :tutor, depending on who 'ordered'
  # the censoring. If both prof and tutor said no, :tutor is returned.
  def censor_comments?
    tutor_ok = censor_unknown? || censor_none?
    prof_ok = profs.none? { |p| p.censor_everything? }
    may_show = tutor_ok && prof_ok
    #~ reason = may_show ? :none : (tutor_ok ? :prof : :tutor)
    return !may_show#, reason
  end

  # Evaluates this tutor only.
  def evaluate
    I18n.locale = course.language

    # if evaluating a single tutor, then usually to give her the results
    allow_censoring = false

    evalname = "#{abbr_name} (#{term.title}; #{course.title})"
    b = ERB.new(RT.load_tex("preamble")).result(binding)
    b << RT.load_tex_definitions(allow_censoring)
    b << "\\selectlanguage{#{I18n.t :tex_babel_lang}}\n"
    b << %(\\let\\cleardoublepage\\newpage\n)


    facultylong = faculty.longname
    term_title = { :short => term.title, :long => term.longtitle }
    b << ERB.new(RT.load_tex("preface")).result(binding)
    b << course.eval_lecture_head

    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      return b
    end

    # walk all questions, one section at a time. Simplified version of
    # the same loop in courses.rb#evaluate. Only one tutor is relevant
    # here.
    form.sections.each do |section|
      questions = Array.new(section.questions)
      # walk all questions in this section
      while !questions.empty?
        # find all questions in this sections until repeat_for changes
        repeat_for = questions.first.repeat_for
        block = []
        while !questions.empty? && questions.first.repeat_for == repeat_for
          block << questions.shift
        end

        # now evaluate that block of questions
        if repeat_for == :tutor
          s = section.any_title
          b << eval_block(block, s, allow_censoring)
        end
      end
    end

    return b + '\end{document}'
  end

  # evaluates the given question and prepends a section header with the
  # given name. Set allow_censoring to false, to forcibly overwrite censor
  # settings of this tutor (i.e. censor nothing). Set it to true to
  # censor depending on setting in tutor’s details.
  def eval_block(questions, section, allow_censoring)
    b = RT.include_form_variables(self)
    # may be used to reference a specific tutor. For example, the tutor_
    # overview visualizer does this.
    b << RT.small_header(section)

    b << "\\label{tutor#{self.id}}\n"
    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      return b
    end

    cen_msg = nil

    prof_censor = profs.any? { |p| p.censor_everything? }
    if prof_censor
      # if the tutor censors at all, upgrade the blame to general if any
      # prof censors as well. The use case is prof: everything and tutor:
      # comments only. In that case a "comments only" message would be
      # shown, but the stats also censored. Thus, the message is upgraded
      # and the tutor blamed for it.
      cen_msg = :blocked_by_prof
      cen_msg = :general if censor_own_comments_and_stats? || censor_own_comments?
    else
      cen_msg = :comments_only if censor_own_comments?
      cen_msg = :general if censor_own_comments_and_stats?
    end

    b << I18n.t(cen_msg,
        :scope => [:censor, :tutors],
        :name => abbr_name) + "\n\n" if allow_censoring && !cen_msg.nil?

    tut_db_col = form.get_tutor_question.db_column.to_sym

    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            # this tutor only
            {:barcode => course.barcodes, tut_db_col => tutnum},
            # all tutors available
            {:barcode => faculty.barcodes},
            self,
            allow_censoring && (q.comment? ? censor_comments? : censor_stats?)
          )
    end
    b
  end

  def tutnum
    course.tutors.index(self) + 1
  end

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    return 0 if course.profs.empty? || form.get_tutor_question.nil?
    tutor_db_column = form.get_tutor_question.db_column.to_sym
    RT.count(form.db_table, {:barcode => course.barcodes, \
      tutor_db_column => tutnum})
  end

  private
  # quick access to some variables and classes
  SCs = Seee::Config.settings
end
