require File.dirname(__FILE__) + '/../test_helper'

class ProfsControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:profs)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_prof
    assert_difference('Prof.count') do
      post :create, :prof => { }
    end

    assert_redirected_to prof_path(assigns(:prof))
  end

  def test_should_show_prof
    get :show, :id => profs(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => profs(:one).id
    assert_response :success
  end

  def test_should_update_prof
    put :update, :id => profs(:one).id, :prof => { }
    assert_redirected_to prof_path(assigns(:prof))
  end

  def test_should_destroy_prof
    assert_difference('Prof.count', -1) do
      delete :destroy, :id => profs(:one).id
    end

    assert_redirected_to profs_path
  end
end
