require File.dirname(__FILE__) + '/../test_helper'

class SemestersControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:semesters)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_semester
    assert_difference('Semester.count') do
      post :create, :semester => { }
    end

    assert_redirected_to semester_path(assigns(:semester))
  end

  def test_should_show_semester
    get :show, :id => semesters(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => semesters(:one).id
    assert_response :success
  end

  def test_should_update_semester
    put :update, :id => semesters(:one).id, :semester => { }
    assert_redirected_to semester_path(assigns(:semester))
  end

  def test_should_destroy_semester
    assert_difference('Semester.count', -1) do
      delete :destroy, :id => semesters(:one).id
    end

    assert_redirected_to semesters_path
  end
end
