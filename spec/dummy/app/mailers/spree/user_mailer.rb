module Spree
  class UserMailer < BaseMailer
    before_filter :set_mail_type
    def reset_password_instructions(user, token, *args)
      @user = user
      @edit_password_reset_url = spree.edit_spree_user_password_url(:reset_password_token => token, :host => Spree::Store.current.url)

      @subject = "#{@user.company.name} "
      @subject += @user.sign_in_count > 0 ? "Password Reset on " : "Registration on "
      @subject += "#{Spree::Store.current.name}"

      mail to: user.email, from: from_address, subject: @subject
    end

    def confirmation_instructions(user, token, opts={})
      @confirmation_url = spree.spree_user_confirmation_url(:confirmation_token => token, :host => Spree::Store.current.url)

      mail to: user.email, from: from_address, subject: Spree::Store.current.name + ' ' + I18n.t(:subject, :scope => [:devise, :mailer, :confirmation_instructions])
    end

    private
    def set_mail_type
      @mail_type = "user"
    end

  end
end
