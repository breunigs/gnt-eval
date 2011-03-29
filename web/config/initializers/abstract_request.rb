# rails 2.2.2 backwards compatibility as per
# http://www.ruby-forum.com/topic/183811#807459
module ActionController
  class AbstractRequest < ActionController::Request
    def self.relative_url_root=(path)
      ActionController::Base.relative_url_root=(path)
    end
    def self.relative_url_root
      ActionController::Base.relative_url_root
    end
  end
end
