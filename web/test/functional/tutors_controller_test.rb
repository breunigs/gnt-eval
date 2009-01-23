require File.dirname(__FILE__) + '/../test_helper'

class TutorsControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:tutors)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_tutor
    assert_difference('Tutor.count') do
      post :create, :tutor => { }
    end

    assert_redirected_to tutor_path(assigns(:tutor))
  end

  def test_should_show_tutor
    get :show, :id => tutors(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => tutors(:one).id
    assert_response :success
  end

  def test_should_update_tutor
    put :update, :id => tutors(:one).id, :tutor => { }
    assert_redirected_to tutor_path(assigns(:tutor))
  end

  def test_should_destroy_tutor
    assert_difference('Tutor.count', -1) do
      delete :destroy, :id => tutors(:one).id
    end

    assert_redirected_to tutors_path
  end
end
