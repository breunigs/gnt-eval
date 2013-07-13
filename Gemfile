source "http://rubygems.org"

gem "rake"
gem "rails",           "3.2.11"
gem "jquery-rails",    "2.1.2"
gem "jquery_datepicker"

# replaces WebRick to get rid of the content length warnings. See
# http://stackoverflow.com/questions/9612618/
# Also required for multithreaded Rails. See
# http://www.wordchuck.com/en/website/blogs/4
gem "thin"

# rails plugin that allows stripping attributes easily
gem "strip_attributes"

# rails handling of enumerated attributes
gem "enumerated_attribute", "0.2.16"

gem "work_queue",      ">=2.0"
gem "open4"
gem "fastimage",	"1.2.13"

# Proper unicode downcase and the like
gem "unicode_utils"

group :production do
end

# Gems used only for assets and not required in production environments
# by default.
group :assets do
  gem "sass-rails",   "~> 3.2.5"
  gem "coffee-rails", "~> 3.2.2"
  gem "uglifier", ">= 1.0.3"
  gem "therubyracer"
  gem "yui-compressor"
end

group :test do
  gem "shoulda"
end

# Databases ############################################################
# See http://stackoverflow.com/questions/5769352/ why rails-dbi is
# required
gem "rails-dbi", :require => "dbi"

gem "mysql2"
gem "dbd-mysql"

gem "pg"
gem "dbd-pg"

# intended for debugging, but allow for production as well
gem "sqlite3"
gem "dbd-sqlite3"



# Gems only required in Rakefile and/or rakefiles/*
group :rakefiles do
  gem "mechanize" # only used in rakefiles/import.rb
  gem "text" # only used in rakefiles/import.rb via lib/friends.rb
end

# gems required for OMR
group :pest do
  gem "gtk2", "~> 1.1.5"
  gem "rmagick", :require => "RMagick"
end

