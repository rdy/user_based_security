module UserBasedSecurity
  module ActionController
    def self.included(controller)
      controller.module_eval do
        include InstanceMethods
        alias_method_chain :perform_action_without_filters, :user_based_security
      end
    end

    module InstanceMethods
      def perform_action_without_filters_with_user_based_security
        assert_security(params[:action])
        perform_action_without_filters_without_user_based_security
      end

      def assert_security(action)
        if respond_to?("can_#{action}?")
          die!(action) unless send("can_#{action}?")
        elsif respond_to?("can_access?")
          die!(action) unless can_access?
        end
      end

      def die!(action)
        raise SecurityTransgression, "User '#{current_user}' may not #{action} #{self.inspect}"
      end
    end
  end

  module ActiveRecord
    VERB_TO_QUESTION_METHOD = {
      :create => :creatable_by?,
      :update => :updatable_by?,
      :destroy => :destroyable_by?,
      :read => :readable_by?
    }

    def self.included(active_record)
      active_record.module_eval do
        extend ClassMethods
        include InstanceMethods

        cattr_accessor :permission_check_passed

        class << self
          alias_method_chain :find, :security_check
        end

        alias_method_chain :create, :security_check
        alias_method_chain :update, :security_check
        alias_method_chain :destroy, :security_check
        alias_method_chain :create_or_update, :security_check
      end
    end

    module ClassMethods
      def find_with_security_check(*args)
        returning find_without_security_check(*args) do |found|
          if found.is_a?(::ActiveRecord::Base) && !permission_check_passed
            found.assert_security(:read)
          end
        end
      end
    end

    module InstanceMethods
      def create_with_security_check(*args)
        action_with_security_check(:create, :create, *args)
      end

      def update_with_security_check(*args)
        action_with_security_check(:update, :update, *args)
      end

      def destroy_with_security_check(*args)
        action_with_security_check(:destroy, :destroy, *args)
      end

      def create_or_update_with_security_check(*args)
        action_with_security_check(new_record? ? :create : :update, :create_or_update, *args)
      end

      def action_with_security_check(action, method, *args)
        if !self.class.permission_check_passed
          assert_security(action)
          self.class.permission_check_passed = true
          begin
            self.send("#{method}_without_security_check", *args)
          ensure
            self.class.permission_check_passed = false
          end
        else
          self.send("#{method}_without_security_check", *args)
        end
      end

      def should_check_security?(verb)
        User.current_user and self.respond_to?(VERB_TO_QUESTION_METHOD[verb])
      end

      def die!(verb)
        raise SecurityTransgression, "User '#{User.current_user}' may not #{verb} #{self.class.to_s}[#{self.id}]"
      end

      def assert_security(verb)
        if should_check_security?(verb) && !User.current_user.send("can_#{verb.to_s}?", self)
          die!(verb)
        end
      end
    end
  end
end