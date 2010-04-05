require 'user_based_security'
ActionController::Base.class_eval do
  include UserBasedSecurity::ActionController
end

ActiveRecord::Base.class_eval do
  include UserBasedSecurity::ActiveRecord
end