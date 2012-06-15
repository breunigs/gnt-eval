# Fixes relative links when deployed to a subdirectory.
# Rails Bug: https://github.com/rails/rails/issues/4308
# Fix from https://github.com/apotonick/cells/issues/35#issuecomment-704010

fail unless ActionDispatch::Routing::RouteSet
module ActionDispatch
    module Routing
        class RouteSet
            alias url_for__ptsroot__ url_for
            def url_for(options = {})
                options[:script_name] = ENV['RAILS_RELATIVE_URL_ROOT'] if options.kind_of?(Hash)
                options = Base.relative_url_root.to_s + options if
                options.kind_of?(String) and options.starts_with?('/')
                url_for__ptsroot__(options)
            end
        end
    end
end

