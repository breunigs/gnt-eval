# encoding: utf-8

require "test_helper"

class HitmeCompleteFlowTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end

  test "overview and assign work" do
    cookies[:username] = "tester"

    get "/hitme"
    assert_response :success

    get "/hitme/assign_work"
    assert_response :success
    # manually clear session because there’s no JavaScript which does
    # that for us, and we don’t want to wait for the timeout
    delete_session

    # test different buttons
    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "Pic", :id => pics(:one).id, :save_and_skip => true}
    assert_equal "/hitme/assign_work", path
    assert_equal nil, flash[:notice]
    delete_session

    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "Pic", :id => pics(:one).id, :save_and_quit => true}
    assert_equal "/hitme", path
    assert_equal "Changes have been saved.", flash[:notice]
    delete_session

    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "Pic", :id => pics(:one).id, :save_and_work => true}
    assert_equal "/hitme/assign_work", path
    assert_equal "Changes have been saved.", flash[:notice]
    delete_session

    # update the rest of the comments
    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "Pic", :id => pics(:two).id, :save_and_work => true}
    assert_equal "/hitme/assign_work", path
    delete_session

    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "CPic", :id => c_pics(:three).id, :save_and_work => true}
    assert_equal "/hitme/assign_work", path
    delete_session

    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "CPic", :id => c_pics(:four).id, :save_and_work => true}
    assert_equal "/hitme/assign_work", path
    delete_session

    assert_equal 0, Hitme.get_all_comments_by_step(0).size

    # now we’re in step=1, i.e. proofreading
    get "/hitme/assign_work"
    assert_response :success
    delete_session

    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "Pic", :id => pics(:one).id, :save_and_quit => true}
    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "Pic", :id => pics(:two).id, :save_and_quit => true}
    assert_equal 1, Hitme.get_all_combinable_tutors.size
    assert_equal 0, Hitme.get_all_combinable_courses.size
    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "CPic", :id => c_pics(:three).id, :save_and_quit => true}
    post_via_redirect "/hitme/save_comment", {:text => "testtext", :type => "CPic", :id => c_pics(:four).id, :save_and_quit => true}
    delete_session
    assert_equal 1, Hitme.get_all_combinable_tutors.size
    assert_equal 1, Hitme.get_all_combinable_courses.size
    assert_equal 0, Hitme.get_all_comments_by_step(0).size
    assert_equal 0, Hitme.get_all_comments_by_step(1).size
    assert_equal 0, Hitme.get_all_final_checkable.size

    # now we’re in step=2, i.e. combining
    get "/hitme/assign_work"
    assert_response :success
    assert assigns(:workon)
    # can’t be type/proof anymore, but not yet final
    assert_template :combine
    delete_session

    post_via_redirect "/hitme/save_combination", {:text => "testtext", :type => "Tutor", :id => tutors(:hitmeTutor).id, :save_and_skip => true}
    assert_equal "/hitme/assign_work", path
    assert_equal nil, flash[:notice]
    assert_equal 1, Hitme.get_all_combinable_tutors.size

    post_via_redirect "/hitme/save_combination", {:text => "testtext", :type => "Tutor", :id => tutors(:hitmeTutor).id, :save_and_quit => true}
    assert_equal "/hitme", path
    assert_equal "Changes have been saved.", flash[:notice]
    assert_equal nil, flash[:warning]
    assert_equal 0, Hitme.get_all_combinable_tutors.size

    post_via_redirect "/hitme/save_combination", {:text => "testtext", :type => "Course", :id => courses(:hitmeCourse).id, :save_and_quit => true}
    assert_equal "/hitme", path
    assert_equal "Changes have been saved.", flash[:notice]
    assert_equal nil, flash[:warning]
    assert_equal 0, Hitme.get_all_combinable_courses.size

    # now we’re in step=3, i.e. final check/moving comments
    assert_equal 1, Hitme.get_all_final_checkable.size
    delete_session

    get "/hitme/assign_work"
    assert_response :success
    assert assigns(:workon)
    assert_template :final_check
    delete_session

    post_via_redirect "/hitme/save_final_check", {:course => "coursetext", :id => courses(:hitmeCourse).id, :tutor => {tutors(:hitmeTutor).id => "tutortext"}, :save_and_quit => true}
    assert_equal "Save successful.", flash[:notice]
    assert_equal "/hitme", path
    assert_equal 0, Hitme.get_all_final_checkable.size

  end


  private
  def delete_session(cont = nil, id = nil)
    return Session.unscoped.delete_all if cont.nil?
    id.nil? \
      ? Session.unscoped.delete_all(:cont => cont) \
      : Session.unscoped.delete_all(:cont => cont, :viewed_id => id)
  end
end
