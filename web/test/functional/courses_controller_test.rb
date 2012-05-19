# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class CoursesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:courses)
    assert_select "h1", 1
  end

  def test_should_get_new
    get :new
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_get_preview
    get :preview
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_create_course
    assert_difference('Course.count') do
      post :create, :course => {
        :semester_id => semesters(:winterTerm).id,
        :title => "Herp A Derp",
        :students => "123",
        :evaluator => "bruno",
        :form_id => forms(:someFormForWT).id,
        :language => "en",
        :faculty_id => faculties(:mathFac).id
      }
    end
    assert_redirected_to course_path(assigns(:course))
  end

  def test_should_show_course
    get :show, :id => courses(:mathSummerCourse).id
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_get_edit
    get :edit, :id => courses(:mathSummerCourse).id
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_update_course
    put :update, :id => courses(:mathSummerCourse).id, :course => {
      :students => 777
    }
    assert_redirected_to course_path(assigns(:course))
  end

  def test_should_not_destroy_critical_course
    assert_no_difference('Course.count') do
      delete :destroy, :id => courses(:mathSummerCourse).id
      assert_not_nil(course_profs(:oneA))
      assert_not_nil(course_profs(:oneB))
    end

    assert_redirected_to courses_path
  end

  def test_should_destroy_course_and_associated_stuff
    assert_difference('Course.count', -1) do
      assert_difference('CourseProf.count', -1) do
        assert_difference('Tutor.count', -1) do
          delete :destroy, :id => courses(:physWinterCourse).id
        end
      end
    end

    assert_redirected_to courses_path
  end
end
