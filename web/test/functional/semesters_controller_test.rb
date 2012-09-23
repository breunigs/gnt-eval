# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class SemestersControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:semesters)
    assert_select "h1", 1
  end

  def test_should_get_new
    get :new
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_create_semester
    assert_difference('Semester.count') do
      post :create, :semester => {
        :firstday => DateTime.now,
        :lastday => DateTime.now + 1,
        :title => "some Term",
        :longtitle => "look, some term it is!",
        :critical => true
      }
    end

    assert_redirected_to semesters_path
  end

  def test_should_get_edit
    get :edit, :id => semesters(:winterTerm).id
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_update_semester
    put :update, :id => semesters(:winterTerm).id, :semester => {
      :critical => true
    }
    assert_redirected_to semesters_path
  end

  def test_should_destroy_semester
    assert_difference('Semester.count', -1) do
      delete :destroy, :id => semesters(:emptyTerm).id
    end

    assert_redirected_to semesters_path
  end

  test "should not delete semester with courses" do
    assert_no_difference('Semester.count') do
      delete :destroy, :id => semesters(:winterTerm).id
    end

    assert_redirected_to semesters_path
  end
end
