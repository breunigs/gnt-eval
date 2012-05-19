# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class CourseProfsControllerTest < ActionController::TestCase
  def test_should_render_form
    post :print, :id => course_profs(:oneA).id
    assert_response :success
  end
end
