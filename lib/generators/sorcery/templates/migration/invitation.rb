class SorceryInvitation < ActiveRecord::Migration
  def self.up
    add_column :<%= model_class_name.tableize %>, :invitation_token, :string, :default => nil
    add_column :<%= model_class_name.tableize %>, :invitation_token_expires_at, :datetime, :default => nil
    add_column :<%= model_class_name.tableize %>, :invitation_email_sent_at, :datetime, :default => nil
    add_column :<%= model_class_name.tableize %>, :invitation_accepted_at, :datetime, :default => nil

    add_index :<%= model_class_name.tableize %>, :invitation_token
  end

  def self.down
    remove_index :<%= model_class_name.tableize %>, :invitation_token

    remove_column :<%= model_class_name.tableize %>, :invitation_accepted_at
    remove_column :<%= model_class_name.tableize %>, :invitation_email_sent_at
    remove_column :<%= model_class_name.tableize %>, :invitation_token_expires_at
    remove_column :<%= model_class_name.tableize %>, :invitation_token
  end
end