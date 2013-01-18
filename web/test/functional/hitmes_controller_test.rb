# encoding: utf-8

require 'test_helper'

class HitmesControllerTest < ActionController::TestCase
  def test_should_get_overview
    get :overview
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_preview_random_text
    post :preview_text, :text => "Hi, I’m a \\LaTeX{} test text"
    assert_response :success
    assert_select ".error", 0
    assert_select "img", 1
    post :preview_text, :text => "\\textrightarrow %Hi, I’m a comment "
    assert_response :success
    assert_select ".error", 0
    assert_select "img", 1
  end

  def test_skipping_comment_does_not_advance_step
    assert_no_difference(lambda { Hitme.get_all_comments_by_step(0).size }) do
      post :save_comment, :text => "testtype1", :type => "Pic",
        :id => pics(:one).id, :save_and_skip => true
    end
    pics(:one).reload
    assert_equal("testtype1", pics(:one).text)
    assert_redirected_to :hitme_assign_work
  end

  def test_course_combination_save_updates_text
    assert_no_difference(lambda { Hitme.get_all_combinable_courses.size }) do
      post :save_combination, :text => "Test1234", :type => "Course",
        :id => courses(:hitmeCourse).id, :save_and_skip => true
    end
    courses(:hitmeCourse).reload
    assert_equal("Test1234", courses(:hitmeCourse).comment)
    assert_redirected_to :hitme_assign_work
  end


  def test_final_check_saves_data
    assert_no_difference(lambda { Hitme.get_all_final_checkable.size }) do
      post :save_final_check, {:course => "coursetext", :id => courses(:hitmeCourse).id, :tutor => {tutors(:hitmeTutor).id => "tutortext"}, :save_and_skip => true}
    end
    courses(:hitmeCourse).reload
    tutors(:hitmeTutor).reload
    assert_equal("coursetext", courses(:hitmeCourse).comment)
    assert_equal("tutortext", tutors(:hitmeTutor).comment)
    assert_redirected_to :hitme_assign_work
  end

  def test_save_final_check_works_for_courses_without_tutor
    assert_no_difference(lambda { Hitme.get_all_final_checkable.size }) do
      post :save_final_check, {:course => "coursetext12", :id => courses(:courseWithoutTutors).id, :save_and_skip => true}
      assert_response :redirect
    end
    courses(:courseWithoutTutors).reload
    assert_equal("coursetext12", courses(:courseWithoutTutors).comment)
    assert_redirected_to :hitme_assign_work
  end
end
