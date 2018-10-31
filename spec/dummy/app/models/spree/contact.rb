module Spree
  class Contact < Spree::Base
    include Spree::Emailable
    belongs_to :user
    belongs_to :company

    validates :company_id, presence: true
    validates :email, uniqueness: {case_sensitive: false, scope: :company_id}, allow_blank: true
    validate  :same_email_as_user
    validate  :user_outside_of_company
    validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, allow_blank: true

    has_many :contact_accounts, class_name: 'Spree::ContactAccount', foreign_key: :contact_id, primary_key: :id

    has_many :accounts, through: :contact_accounts, source: :account

    before_save :associate_user, if: Proc.new {|contact| contact.email_changed? || contact.user.nil?}
    before_save :set_full_name

    after_save :assign_user_accounts, unless: Proc.new{|contact| contact.invited_at.nil?}

    before_destroy :prep_for_deletion

    self.whitelisted_ransackable_attributes = %w[full_name first_name last_name email position user_id account_ids phone invited_at]
    self.whitelisted_ransackable_associations = %w[user accounts]

    def self.find_by_email(email_address)
      where('email ilike ?', email_address).first
    end

    def account_ids=(arr)
      super(arr.reject(&:blank?).map(&:to_i))
    end

    def name
      self.full_name
    end

    def set_full_name
      if self.first_name.present? && self.last_name.present?
        self.full_name = "#{first_name} #{last_name}".strip
      elsif self.first_name.present?
        self.full_name = self.first_name
      elsif self.last_name.present?
        self.full_name = self.last_name
      else
        self.full_name = ""
      end

      self.full_name
    end

    def associate_user
      self.user_id = Spree::User.find_by_email(self.email).try(:id)
    end

    def email_greeting
      if self.first_name.present? && self.last_name.present?
        "#{self.first_name} #{self.last_name}"
      elsif self.first_name.present?
        self.first_name
      elsif self.last_name.present?
        self.last_name
      elsif @contact.try(:accounts).try(:count) == 1
        self.accounts.first.try(:fully_qualified_name)
      elsif self.email.present?
        self.email
      else
        ""
      end
    end

    def set_acct_primary_to_other_or_nil
      result = nil

      # go through accounts of contact and ...
      self.account_ids.each do |account_id|
        account = self.company.customer_accounts.find_by_id(account_id)
        # ... check if any of the accounts have this contact as the primary
        if account.try(:primary_cust_contact_id) == self.id
          result ||= true if account.replace_or_remove_primary_contact(self.id) # replace or remove primary contact
        end
      end

      result
    end

    def can_invite?
      return false unless self.account_ids.present? && self.valid_emails.present?
      return true unless self.user
      !self.user_has_access?
    end

    def can_resend_invite?
      self.invited_at.present? && self.can_invite?
    end

    def user_has_access?
      return false unless self.user
      self.user.user_accounts.where(account_id: self.account_ids).present?
    end

    def can_mark_invited?
      invited_at.nil? && user_has_access?
    end

    def assign_user_accounts
      return unless user

      acc_ids = contact_accounts.pluck(:account_id)
      if acc_ids.empty?
        user.user_accounts.where(account_id: company.customer_account_ids).delete_all
      else
        user.user_accounts.where(account_id: company.customer_account_ids)
                          .where.not(account_id: acc_ids)
                          .delete_all
        #ActiveRecord will handle creating records and duplicate ids!
        user.account_ids += user.company.vendor_accounts.where(id: acc_ids).ids
      end
    end

    def accessible_accounts
      return [] unless user
      user.user_accounts.where(account_id: company.customer_account_ids)
    end

    def valid_account_ids?(acc_ids)
      return true if acc_ids.blank?

      valid = true
      cust_ids = company.customer_accounts.where(id: acc_ids).pluck(:customer_id).uniq
      if cust_ids.count > 1
        self.errors.add(:base, Spree.t('errors.contact.unrelated_accounts'))
        valid = false
      end
      return valid unless user && invited_at.present?
      cust_id = cust_ids.first.to_i
      current_cust_id = accounts.first.try(:customer_id)

      return valid if cust_id == user.company_id

      if current_cust_id == user.company_id && current_cust_id != cust_id
        self.errors.add(:base, Spree.t('errors.contact.invalid_company', company_name: user.company.name))
        valid = false
      end

      valid
    end

    private

    def prep_for_deletion
      set_acct_primary_to_other_or_nil
      if self.user.presence
        self.user.user_accounts.where(account_id: self.contact_accounts.pluck(:account_id)).destroy_all
      end
      self.contact_accounts.destroy_all
    end

    def same_email_as_user
      return true if user.nil?
      return true if user.email.downcase == email.downcase

      self.errors.add(:email, Spree.t('errors.contact.same_email_as_user', user_email: user.email))
      false
    end

    def user_outside_of_company
      return true if company.users.where('email ilike ?', email).empty?

      self.errors.add(:email, Spree.t('errors.contact.email_is_internal'))
      false
    end

  end
end
