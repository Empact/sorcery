shared_examples_for "rails_3_invitation_model" do
  let(:user_attributes) {
    {
      email: 'test@example.com',
      username: 'Test'
    }
  }

  # ----------------- PLUGIN CONFIGURATION -----------------------
  describe User, "loaded plugin configuration" do

    before(:all) do
      sorcery_reload!([:invitation], :invitation_mailer => ::SorceryMailer)
    end

    after(:each) do
      User.sorcery_config.reset!
    end

    context "API" do
      specify { User.should respond_to(:deliver_invitation_instructions!) }

      it "should respond to .load_from_invitation_token" do
        User.should respond_to(:load_from_invitation_token)
      end
    end

    it "should allow configuration option 'invitation_token_attribute_name'" do
      sorcery_model_property_set(:invitation_token_attribute_name, :my_code)
      User.sorcery_config.invitation_token_attribute_name.should equal(:my_code)
    end

    it "should allow configuration option 'invitation_mailer'" do
      sorcery_model_property_set(:invitation_mailer, TestUser)
      User.sorcery_config.invitation_mailer.should equal(TestUser)
    end

    it "should enable configuration option 'invitation_mailer_disabled'" do
      sorcery_model_property_set(:invitation_mailer_disabled, :my_invitation_mailer_disabled)
      User.sorcery_config.invitation_mailer_disabled.should equal(:my_invitation_mailer_disabled)
    end

    it "if mailer is nil and mailer is enabled, throw exception!" do
      expect{
        sorcery_reload!([:invitation], :invitation_mailer_disabled => false)
      }.to raise_error(ArgumentError)
    end

    it "if mailer is disabled and mailer is nil, do NOT throw exception" do
      expect{
        sorcery_reload!([:invitation], :invitation_mailer_disabled => true)
      }.to_not raise_error
    end

    it "should allow configuration option 'invitation_email_method_name'" do
      sorcery_model_property_set(:invitation_email_method_name, :my_mailer_method)
      User.sorcery_config.invitation_email_method_name.should equal(:my_mailer_method)
    end

    it "should allow configuration option 'invitation_expiration_period'" do
      sorcery_model_property_set(:invitation_expiration_period, 16)
      User.sorcery_config.invitation_expiration_period.should equal(16)
    end

    it "should allow configuration option 'invitation_email_sent_at_attribute_name'" do
      sorcery_model_property_set(:invitation_email_sent_at_attribute_name, :blabla)
      User.sorcery_config.invitation_email_sent_at_attribute_name.should equal(:blabla)
    end
  end

  # ----------------- PLUGIN ACTIVATED -----------------------
  describe User, "when activated with sorcery" do

    before(:all) do
      sorcery_reload!([:invitation], :invitation_mailer => ::SorceryMailer)
    end

    before(:each) do
      User.delete_all
    end

    after(:each) do
      Timecop.return
    end

    it "load_from_invitation_token should return user when token is found" do
      user = User.deliver_invitation_instructions!(user_attributes)
      User.load_from_invitation_token(user.invitation_token).should == user
    end

    it "load_from_invitation_token should NOT return user when token is NOT found" do
      User.deliver_invitation_instructions!(user_attributes)
      User.load_from_invitation_token("a").should == nil
    end

    it "load_from_invitation_token should return user when token is found and not expired" do
      sorcery_model_property_set(:invitation_expiration_period, 500)
      user = User.deliver_invitation_instructions!(user_attributes)
      User.load_from_invitation_token(user.invitation_token).should == user
    end

    it "load_from_invitation_token should NOT return user when token is found and expired" do
      sorcery_model_property_set(:invitation_expiration_period, 0.1)
      user = User.deliver_invitation_instructions!(user_attributes)
      Timecop.travel(Time.now.in_time_zone+0.5)
      User.load_from_invitation_token(user.invitation_token).should == nil
    end

    it "load_from_invitation_token should always be valid if expiration period is nil" do
      sorcery_model_property_set(:invitation_expiration_period, nil)
      user = User.deliver_invitation_instructions!(user_attributes)
      User.load_from_invitation_token(user.invitation_token).should == user
    end

    it "load_from_invitation_token should return nil if token is blank" do
      User.load_from_invitation_token(nil).should == nil
      User.load_from_invitation_token("").should == nil
    end

    describe "#deliver_invitation_instructions!" do
      it "should generate a invitation_token" do
        user = User.deliver_invitation_instructions!(user_attributes)
        user.invitation_token.should_not be_nil
      end

      it "the invitation_token should be random" do
        user = User.deliver_invitation_instructions!(user_attributes)
        old_password_code = user.invitation_token
        user = User.deliver_invitation_instructions!(user_attributes)
        user.invitation_token.should_not == old_password_code
      end

      context 'for an existing invitee' do
        let(:username_attributes) { {username: 'foo'} }
        before do
          @existing_invitee = User.deliver_invitation_instructions!(user_attributes)
        end

        it 'acts on the same user' do
          invitee = User.deliver_invitation_instructions!(user_attributes)
          invitee.should == @existing_invitee
        end

        it 'resends the invitation' do
          expect {
            User.deliver_invitation_instructions!(user_attributes)
          }.to change(ActionMailer::Base.deliveries, :size).by(1)
        end
      end

      context 'for a full user' do
        before do
          @user = create_new_user
        end

        it 'does nothing' do
          expect {
            User.deliver_invitation_instructions!(username: @user.username)
          }.to_not change(ActionMailer::Base.deliveries, :size)
        end
      end

      context 'with an inviter' do
        let(:inviter) { create_new_user(:username => 'inviter', :email => 'inviter@example.com') }

        it "sets the users's #invited_by association" do
          user = User.deliver_invitation_instructions!(user_attributes, inviter)
          user.invited_by.should == inviter
        end
      end
    end

    describe "#accept_invitation" do
      before do
        @user = User.deliver_invitation_instructions!(user_attributes)
        @accepted_user = User.accept_invitation!(@user.invitation_token)
      end

      it 'should accept the right user' do
        @accepted_user.should == @user
      end

      it 'should clear the invitation token' do
        @accepted_user.invitation_token.should == nil
      end

      it 'should mark the user as having accepted their invitation' do
        @accepted_user.invitation_accepted_at.should_not == nil
      end
    end

    context "mailer is enabled" do
      it "should send an email on reset" do
        expect {
          User.deliver_invitation_instructions!(user_attributes)
        }.to change(ActionMailer::Base.deliveries, :size).by(1)
      end
    end

    context "mailer is disabled" do

      before(:all) do
        sorcery_reload!([:invitation], :invitation_mailer_disabled => true, :invitation_mailer => ::SorceryMailer)
      end

      it "should not send an email on reset" do
        expect {
          User.deliver_invitation_instructions!(user_attributes)
        }.to_not change(ActionMailer::Base.deliveries, :size)
      end
    end

  end
end