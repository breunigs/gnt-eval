require 'test_helper'

class FacultiesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:faculties)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create faculty" do
    assert_difference('Faculty.count') do
      post :create, :faculty => { }
    end

    assert_redirected_to faculty_path(assigns(:faculty))
  end

  test "should show faculty" do
    get :show, :id => faculties(:one).id
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => faculties(:one).id
    assert_response :success
  end

  test "should update faculty" do
    put :update, :id => faculties(:one).id, :faculty => { }
    assert_redirected_to faculty_path(assigns(:faculty))
  end

  test "should destroy faculty" do
    assert_difference('Faculty.count', -1) do
      delete :destroy, :id => faculties(:one).id
    end

    assert_redirected_to faculties_path
  end
end
