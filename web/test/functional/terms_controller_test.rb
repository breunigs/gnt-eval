# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class TermsControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:terms)
    assert_select "h1", 1
  end

  def test_should_get_new
    get :new
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_create_term
    assert_difference('Term.count') do
      post :create, :term => {
        :firstday => DateTime.now,
        :lastday => DateTime.now + 1,
        :title => "some Term",
        :longtitle => "look, some term it is!",
        :critical => true
      }
    end

    assert_redirected_to terms_path
  end

  def test_should_get_edit
    get :edit, :id => terms(:winterTerm).id
    assert_response :success
    assert_select "h1", 1
  end

  def test_should_update_term
    put :update, :id => terms(:winterTerm).id, :term => {
      :critical => true
    }
    assert_redirected_to terms_path
  end

  def test_should_destroy_term
    assert_difference('Term.count', -1) do
      delete :destroy, :id => terms(:emptyTerm).id
    end

    assert_redirected_to terms_path
  end

  test "should not delete term with courses" do
    assert_no_difference('Term.count') do
      delete :destroy, :id => terms(:winterTerm).id
    end

    assert_redirected_to terms_path
  end
end
