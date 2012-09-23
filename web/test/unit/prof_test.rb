# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class ProfTest < ActiveSupport::TestCase
  should_strip_attributes :firstname, :surname, :email
  should have_many(:course_profs)

  def test_attributes_get_trimmed
    p = Prof.create :firstname => " Firstname ",
                    :surname => "\nLastname\t\t  ",
                    :email => " \tstefan+istdoof@mathphys.fsk.uni-heidelberg.de ",
                    :gender => 1

    assert_equal 'Firstname', p.firstname, 'Firstname not trimmed'
    assert_equal 'Lastname', p.surname, 'Surname not trimmed'
    assert_equal 'stefan+istdoof@mathphys.fsk.uni-heidelberg.de', p.email, 'Mail not trimmed'
  end

  def test_lastname_alias
    assert_equal profs(:oliver).surname, profs(:oliver).lastname
  end

  test "variable types of gender related functions" do
    assert_kind_of Symbol, profs(:rebecca).gender
    assert_kind_of String, profs(:rebecca).gender_symbol
  end

  test "critical if there are associated CourseProfs" do
    assert(profs(:jasper).critical?)
  end
end
