# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class CourseProfsControllerTest < ActionController::TestCase
  def test_should_print_form
    post :print, :id => course_profs(:oneA).id
    assert_redirected_to course_path(course_profs(:oneA).course.id)
    assert_nil flash[:error]
  end
end
