# encoding: utf-8

require File.dirname(__FILE__) + '/../test_helper'

class TermTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_sheets_to_go_works
    to_go, quota = Term.sheets_to_go
    assert_not_nil(to_go)
    assert_not_nil(quota)
    assert(quota > 0)
  end
end
