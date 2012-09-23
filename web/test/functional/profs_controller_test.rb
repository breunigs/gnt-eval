# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class ProfsControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:profs)
    assert_select "h1", 1
  end

  def test_should_get_new
    get :new
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_create_prof
    assert_difference('Prof.count') do
      post :create, :prof => {
        :firstname => "Frederic",
        :surname => "Polymath",
        :email => "eval@mathphys.fsk.uni-heidelberg.de",
        :gender => 1
      }
    end

    assert_redirected_to profs_path
  end

  def test_should_get_edit
    get :edit, :id => profs(:rebecca).id
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_update_prof
    put :update, :id => profs(:jasper).id, :prof => { }
    assert_redirected_to profs_path
  end

  def test_should_destroy_prof
    assert_difference('Prof.count', -1) do
      delete :destroy, :id => profs(:stefan).id
    end

    assert_redirected_to profs_path
  end

  def test_should_not_destroy_prof_with_associated_courses
    assert_no_difference('Prof.count') do
      delete :destroy, :id => profs(:rebecca).id
    end

    assert_redirected_to profs_path
  end
end
