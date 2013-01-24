class Session < ActiveRecord::Base
  # the lambda is required so that 30.seconds.ago is not cached and
  # evaluated each time. See http://stackoverflow.com/a/14093331/1684530
  default_scope -> { where("updated_at > ?", 30.seconds.ago) }

  attr_accessible :cont, :ident, :viewed_id

  validates :ident, :format => { :with => /^[a-z0-9]+$/,
    :message => "Only lowercase letters and numbers allowed" }
  validates :ident, :length => { :is => 9 }

  validates :viewed_id, :numericality => { :only_integer => true }

  validates :cont, :format => { :with => /^[a-z]+$/,
    :message => "Only lowercase letters allowed" }
end
