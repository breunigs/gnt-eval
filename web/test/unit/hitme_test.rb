# encoding: utf-8

require 'test_helper'

class HitmeTest < ActiveSupport::TestCase
  def test_tools
    assert_raise(RuntimeError) { Hitme.step_to_text(10) }
  end

  def test_get_all_methods
    assert_equal(Hitme.get_all_comments_by_step(0).size, 4, "There should be exactly four comments in step 0")
    assert_equal(Hitme.get_all_comments_by_step(1).size, 0, "There shouldn’t be any comments in step 1")
    assert_equal(Hitme.get_all_combinable_courses.size, 0, "There shouldn’t be any combinale courses")
    assert_equal(Hitme.get_all_combinable_tutors.size, 0, "There shouldn’t be any combinale tutors")
    assert_equal(Hitme.get_all_final_checkable.size, 0, "There shouldn’t be any final checkables")
  end

  def test_get_workable_methods
    assert_not_nil(Hitme.get_workable_comment_by_step(0))
    assert_nil(Hitme.get_workable_comment_by_step(1))
    assert_nil(Hitme.get_combinable)
    assert_nil(Hitme.get_final_checkable)
  end

  def test_get_all_methods_to_return_array
    assert_kind_of(Array, Hitme.get_all_comments_by_step(0))
    assert_kind_of(Array, Hitme.get_all_comments_by_step(1))
    assert_kind_of(Array, Hitme.get_all_combinable_courses)
    assert_kind_of(Array, Hitme.get_all_combinable_tutors)
    assert_kind_of(Array, Hitme.get_all_final_checkable)
  end
end
