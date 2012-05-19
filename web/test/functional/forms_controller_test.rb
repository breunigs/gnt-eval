# encoding: utf-8

require 'test_helper'

class FormsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:forms)
    assert_select "h1", 1
  end

  test "should get new" do
    get :new
    assert_response :success
    assert_select "h1", 1
  end

  test "should create form" do
    assert_difference('Form.count') do
      post :create, :form => {
        :name => "asdasdasd",
        :semester_id => semesters(:winterTerm).id,
        :content => "an invalid form"
      }
    end

    assert_redirected_to form_path(assigns(:form))
  end

  test "should show form" do
    get :show, :id => forms(:someFormForST).id
    assert_response :success
    assert_select "h1", 1
  end

  test "should get edit" do
    get :edit, :id => forms(:someFormForWT).id
    assert_response :success
    assert_select "h1", 1
  end

  test "should update form" do
    put :update, :id => forms(:someFormForWT).id, :form => { }
    assert_redirected_to form_path(assigns(:form))
  end

  test "should destroy form" do
    assert_difference('Form.count', -1) do
      delete :destroy, :id => forms(:someUnusedForm).id
    end

    assert_redirected_to forms_path
  end
end
