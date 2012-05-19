# encoding: utf-8

require 'test_helper'

class FacultiesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:faculties)
    assert_select "h1", 1
  end

  test "should get new" do
    get :new
    assert_response :success
    assert_select "h1", 1
  end

  test "should create faculty" do
    assert_difference('Faculty.count') do
      post :create, :faculty => {
        :longname => "Faculty of Silly Walks",
        :shortname => "Silly Walkes"
      }
    end

    assert_redirected_to faculties_path
  end

  test "should get edit" do
    get :edit, :id => faculties(:physFac).id
    assert_response :success
    assert_select "h1", 1
  end

  test "should update faculty" do
    put :update, :id => faculties(:physFac).id, :faculty => {
      :shortname => "Silly Walks"
    }
    assert_redirected_to faculties_path
  end

  test "should not delete faculties with attached courses" do
    assert_no_difference('Faculty.count') do
      delete :destroy, :id => faculties(:mathFac).id
    end

    assert_redirected_to faculties_path
  end

  test "should delete faculty without courses" do
    assert_difference('Faculty.count', -1) do
      delete :destroy, :id => faculties(:emptyFac).id
    end

    assert_redirected_to faculties_path
  end
end
