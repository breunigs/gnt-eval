class Hitme < ActiveRecord::Base
  TYPING = 0
  PROOFREADING = 1
  COMBINING = 2
  FINALCHECK = 3
  DONE = 4

  def self.step_to_text(step)
    case step
      when nil then "typing"
      when Hitme::TYPING then "typing"
      when Hitme::PROOFREADING then "proofreading"
      when Hitme::COMBINING then "combining"
      when Hitme::FINALCHECK then "final checking"
      else raise("Undefined step: #{step}")
    end
  end


  # returns all comments that are currently at the specified step.
  # Includes comments that are being worked on right now.
  def self.get_all_comments_by_step(step)
    step = [nil, Hitme::TYPING] if step == Hitme::TYPING
    all = CPic.joins(:course).where("courses.term_id" => self.curr_term, "step" => step)
    all += Pic.joins(:course).where("courses.term_id" => self.curr_term, "step" => step)
    logger.debug "Found #{all.size} comments in step #{step}"
    all
  end

  # find a comment someone can work on.
  def self.get_workable_comment_by_step(step)
    all = self.get_all_comments_by_step(step)
    self.get_workable_sample(all)
  end


  def self.get_combinable
    all = self.get_all_combinable_courses + self.get_all_combinable_tutors
    self.get_workable_sample(all)
  end

  def self.get_all_combinable_courses
    c = Course.includes(:c_pics).where("term_id" => self.curr_term).to_a
    # remove all courses without images
    c.reject! { |x| x.c_pics.none? }
    # remove course if there are any images below COMBINING
    c.reject! { |x| x.c_pics.any? { |p| p.step < Hitme::COMBINING } }
    # remove all tutors if there ALL images are above COMBINING
    c.reject! { |x| x.c_pics.all? { |p| p.step > Hitme::COMBINING } }
    # remove courses that don’t have any text comments
    c.reject! { |x| x.c_pics.all? { |p| p.text.blank? } }
    logger.debug "Found #{c.size} combineable courses"
    c
  end

  def self.get_all_combinable_tutors
    c = Tutor.joins(:course).includes(:pics).where("courses.term_id" => self.curr_term).to_a
    # remove all tutors without images
    c.reject! { |x| x.pics.none? }
    # remove all tutors if there are any images below COMBINING
    c.reject! { |x| x.pics.any? { |p| p.step < Hitme::COMBINING } }
    # remove all tutors if there ALL images are above COMBINING
    c.reject! { |x| x.pics.all? { |p| p.step > Hitme::COMBINING } }
    # remove courses that don’t have any text comments
    c.reject! { |x| x.pics.all? { |p| p.text.blank? } }
    logger.debug "Found #{c.size} combinale tutors"
    c
  end


  def self.get_final_checkable
    # locking is only happening for the course. Hope there will be no
    # collisions for the tutors
    self.get_workable_sample(self.get_all_final_checkable)
  end


  def self.get_all_final_checkable
    c = Course.includes(:c_pics).where("term_id" => self.curr_term).to_a
    c.reject! { |x| x.c_pics.none? && x.tutors.all? { |t| t.pics.none? } }
    # remove course if there are course-images below FINALCHECK
    c.reject! { |x| x.c_pics.any? { |p| p.step < Hitme::FINALCHECK } }
    # remove course if there are tutor-images below FINALCHECK
    c.reject! { |x| x.tutors.any? { |t| t.pics.any? { |p| p.step < Hitme::FINALCHECK } } }
    # remove course if all images are above FINALCHECK
    c.reject! do |x|
      a = x.c_pics.all? { |p| p.step > Hitme::FINALCHECK }
      b = x.tutors.all? { |t| t.pics.all? { |p| p.step > Hitme::FINALCHECK } }
      a && b
    end
    logger.debug "Found #{c.size} final checkables"
    c
  end



  private
  def self.curr_term
    Term.currently_active.map(&:id)
  end

  def self.get_workable_sample(all)
    raise "Expected an array, but got #{all.class}" unless all.is_a?(Array)
    while not (workon = all.sample).nil?
      return workon unless Hitme.is_being_worked_on(workon)
      logger.debug "#{workon.class}=#{workon.id} is being worked on. Skipping."
      # workon is already being worked on by someone else, remove it
      # from the array so it’s not picked again. Deliberately not using
      # all.delete because it may invoke Rails deleting the object.
      all -= [workon]
    end
    nil
  end

  # Checks if the given object is currently being worked on.
  def self.is_being_worked_on(obj)
    # be a little more generous in case the connection is flaky
    Session.unscoped
      .where(["updated_at > ?", 1.minutes.ago])
      .exists?(:cont => obj.class.to_s.pluralize.downcase, :viewed_id => obj.id)
  end
end
