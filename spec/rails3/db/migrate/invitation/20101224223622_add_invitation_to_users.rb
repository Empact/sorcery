class AddInvitationToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :invitation_token, :string, :default => nil
    add_column :users, :invitation_token_expires_at, :datetime, :default => nil
    add_column :users, :invitation_email_sent_at, :datetime, :default => nil
    add_column :users, :invitation_accepted_at, :datetime, :default => nil
  end

  def self.down
    remove_column :users, :invitation_accepted_at
    remove_column :users, :invitation_email_sent_at
    remove_column :users, :invitation_token_expires_at
    remove_column :users, :invitation_token
  end
end