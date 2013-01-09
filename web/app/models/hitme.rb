class Hitme < ActiveRecord::Base
  def self.step_to_text(step)
    case step
      when nil then "typing"
      when 0 then "typing"
      when 1 then "proofreading"
      else raise("Undefined step: #{step}")
    end
  end

  # returns all comments that are currently at the specified step.
  # Includes comments that are being worked on right now.
  def self.get_all_comments_by_step(step)
    step = [nil, 0] if step == 0
    all = CPic.joins(:course).where("courses.term_id" => self.t, "step" => step)
    all += Pic.joins(:course).where("courses.term_id" => self.t, "step" => step)
    all
  end

  # Checks if the given object is currently being worked on.
  def self.is_being_worked_on(obj)
    # be a little more generous in case the connection is flaky
    Session.unscoped
      .where(["updated_at > ?", 1.minutes.ago])
      .exists?(:cont => obj.class.to_s.downcase, :viewed_id => obj.id)
  end

  # find a comment someone can work on.
  def self.get_workable_comment_by_step(step)
    all = self.get_all_comments_by_step(step)

    while not (workon = all.sample).nil?
      return workon unless Hitme.is_being_worked_on(workon)
      # workon is already being worked on by someone else
      all.delete(workon)
    end
    nil
  end

  def self.get_combinable
    (self.get_combinable_courses + self.get_combinable_tutors).sample
  end


  def self.get_all_combinable_courses
    c = Course.includes(:c_pics).where("term_id" => self.t)
    # remove all courses which have comments that are not yet in step 2
    c.reject! { |x| x.c_pics.size == 0 || x.c_pics.size != x.c_pics.where(:step => 2).size }
    c
  end

  def self.get_all_combinable_tutors
    c = Tutor.joins(:course).includes(:pics).where("courses.term_id" => self.t)
    # remove all tutors who have comments that are not yet in step 2
    c.reject! { |x| x.pics.size != x.pics.where(:step => 2) }
    c
  end

  private
  def self.t
    Term.currently_active.map(&:id)
  end
end
