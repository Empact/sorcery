module Sorcery
  module Model
    module Submodules
      module Invitation
        def self.included(base)
          base.sorcery_config.class_eval do
            attr_accessor :invitation_token_attribute_name,              # reset password code attribute name.
                          :invitation_token_expires_at_attribute_name,   # expires at attribute name.
                          :invitation_email_sent_at_attribute_name,      # when was email sent, used for hammering
                                                                             # protection.
                          :invitation_inviter_attribute_name,
                          :invitation_accepted_at_attribute_name,        # set when the user has accepted the invitation

                          :invitation_mailer,                            # mailer class. Needed.

                          :invitation_mailer_disabled,                   # when true sorcery will not automatically
                                                                             # email password reset details and allow you to
                                                                             # manually handle how and when email is sent

                          :invitation_email_method_name,                 # reset password email method on your
                                                                             # mailer class.

                          :invitation_expiration_period                  # how many seconds before the reset request
                                                                             # expires. nil for never expires.


          end

          base.sorcery_config.instance_eval do
            @defaults.merge!(:@invitation_token_attribute_name            => :invitation_token,
                             :@invitation_token_expires_at_attribute_name => :invitation_token_expires_at,
                             :@invitation_email_sent_at_attribute_name    => :invitation_email_sent_at,
                             :@invitation_inviter_attribute_name          => :invited_by_id,
                             :@invitation_accepted_at_attribute_name      => :invitation_accepted_at,
                             :@invitation_mailer                          => nil,
                             :@invitation_mailer_disabled                 => false,
                             :@invitation_email_method_name               => :invitation_email,
                             :@invitation_expiration_period               => nil )

            reset!
          end

          base.extend(ClassMethods)

          base.sorcery_config.after_config << :validate_mailer_defined
        end

        module ClassMethods
          def accept_invitation!(token)
            config = sorcery_config
            invitee = load_from_invitation_token(token)
            if invitee.send(config.invitation_token_attribute_name) == token
              invitee.update_many_attributes(
                config.invitation_accepted_at_attribute_name => Time.now.utc,
                config.invitation_token_attribute_name => nil
              )
            end
            invitee
          end

          def deliver_invitation_instructions!(invitee_attrs, inviter = nil)
            config = sorcery_config

            existing_invitee =
              config.username_attribute_names.map do |username_attribute|
                where(username_attribute => invitee_attrs[username_attribute]).first
              end.first
            if existing_invitee && !existing_invitee.send(config.invitation_token_attribute_name)
              return existing_invitee
            end

            attributes = {
              config.invitation_token_attribute_name => TemporaryToken.generate_random_token,
              config.invitation_email_sent_at_attribute_name => Time.now.in_time_zone,
              config.invitation_inviter_attribute_name => inviter && inviter.id
            }
            if config.invitation_expiration_period && config.invitation_token_expires_at_attribute_name
              attributes[config.invitation_token_expires_at_attribute_name] =
                Time.now.in_time_zone + config.invitation_expiration_period
            end
            invitee = existing_invitee || new(invitee_attrs)
            transaction do
              if invitee.persisted? || invitee.save
                invitee.update_many_attributes(attributes)
                unless config.invitation_mailer_disabled
                  invitee.send(:generic_send_email, :invitation_email_method_name, :invitation_mailer)
                end
              end
              invitee
            end
          end

          def load_from_invitation_token(token)
            token_attr_name = @sorcery_config.invitation_token_attribute_name
            token_expiration_date_attr = @sorcery_config.invitation_token_expires_at_attribute_name
            load_from_token(token, token_attr_name, token_expiration_date_attr)
          end

          protected

          # This submodule requires the developer to define his own mailer class to be used by it
          # when invitation_mailer_disabled is false
          def validate_mailer_defined
            msg = "To use invitation submodule, you must define a mailer (config.invitation_mailer = YourMailerClass)."
            raise ArgumentError, msg if @sorcery_config.invitation_mailer == nil and @sorcery_config.invitation_mailer_disabled == false
          end
        end
      end
    end
  end
end