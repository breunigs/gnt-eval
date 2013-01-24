# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class TutorsControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:tutors)
    assert_select "h1", 1
  end

  def test_should_create_one_tutor
    assert_difference('Tutor.count') do
      post :create, :course_id => courses(:physWinterCourse).id, :tutor => {
        :abbr_name => "The one tutor to teach them all"
      }
    end
    assert_redirected_to course_path(courses(:physWinterCourse))
  end

  def test_should_ignore_duplicate_tutors
    assert_difference('Tutor.count', 2) do
      post :create, :course_id => courses(:physWinterCourse).id, :tutor => {
        :abbr_name => "Duplicate,Duplicate,Duplicate2,Duplicate2"
      }
    end
    assert_redirected_to course_path(courses(:physWinterCourse))
  end

  def test_should_ignore_existing_tutors
    assert_no_difference('Tutor.count') do
      post :create, :course_id => courses(:physWinterCourse).id, :tutor => {
        :abbr_name => "Oliver ist Doof"
      }
    end
    assert_redirected_to course_path(courses(:physWinterCourse))
  end


  def test_should_show_tutor
    get :show, :course_id => tutors(:paul).course_id, :id => tutors(:paul).id
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_get_edit
    get :edit, :course_id => tutors(:oliver).course_id, :id => tutors(:oliver).id
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_update_tutor
    put :update, :course_id => tutors(:oliver).course_id, :id => tutors(:oliver).id, :tutor => {
      :abbr_name => "a new name",
      :comment => "some TeX code here or so"
    }
    a = assigns(:tutor)
    assert_redirected_to course_tutor_path(a.course, a)
  end

  def test_should_not_destroy_tutor_if_term_critical
    assert_no_difference('Tutor.count') do
      # Paul belongs to the summer course, which belongs to the summer
      # term, which is critical.
      delete :destroy, :course_id => tutors(:paul).course_id, :id => tutors(:paul).id
    end

    assert_redirected_to course_path(assigns(:tutor).course)
  end

  def test_should_destroy_tutor
    assert_difference('Tutor.count', -1) do
      delete :destroy, :course_id => tutors(:beccy).course_id, :id => tutors(:beccy).id
    end

    assert_redirected_to course_path(assigns(:tutor).course)
  end
end
