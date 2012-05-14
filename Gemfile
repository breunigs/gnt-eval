source "http://rubygems.org"

gem "rails",           "3.2.3"
gem "jquery-rails"

# See http://stackoverflow.com/questions/5769352/connect-to-sql-server-without-activerecord
# why rails-dbi is required
gem 'rails-dbi', :require => 'dbi'

gem "rmagick"
gem "work_queue",      ">=2.0"
gem "open4"
gem "text"
gem "mechanize"

gem 'mysql2'
gem "dbd-mysql"

gem "pg"
gem "dbd-pg"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
    
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer'
    
  gem 'uglifier', '>= 1.0.3'
end
          
          

# used for debugging
gem "sqlite3"
gem "dbd-sqlite3"

# gems only required for the OMR part of G'n'T Eval
group :pest do
  gem "gtk2"
end
