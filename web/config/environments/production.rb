# encoding: utf-8

Seee::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # even though in production, print full error messages
  config.consider_all_requests_local       = true
  # enable full caching
  config.action_controller.perform_caching = true

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # set to false to disable Rails's static asset server (Apache or nginx will already do this)
  # set to true, to also allow when testing production mode via rails server.
  config.serve_static_assets = true

  # Don’t compress the assets for now. It takes ages and many of the
  # large JS files are already compressed. Also, CSS compression removes
  # the px-instead-of-rem fallback for older browsers.
  config.assets.compress = false

  # don't fallback to assets pipeline if a precompiled asset is missing
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # The following files are not included in the application.{css,js} files. List
  # them here so they get precompiled for production.
  config.assets.precompile += %w(js-yaml.min.js json2yaml.js formeditor.js ace/*.js excanvas.js visualize.jQuery.js correlate.js aceify-textareas.js viewer_count.js jquery.jscroll.js)

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5
end
