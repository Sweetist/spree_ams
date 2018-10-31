Spree::User.class_eval do
  include Spree::Emailable

  validates :firstname, :lastname, presence: true
  store_accessor :settings

  belongs_to :company, class_name: 'Spree::Company', foreign_key: :company_id, primary_key: :id

  has_many :orders, class_name: 'Spree::Order', foreign_key: :user_id, primary_key: :id
  has_many :standing_orders, class_name: 'Spree::StandingOrder', foreign_key: :user_id, primary_key: :id

  has_many :images, as: :viewable, dependent: :destroy, class_name: "Spree::UserImage"

  acts_as_commontator

  has_many :datatable_settings, dependent: :destroy

  has_many :user_accounts, dependent: :destroy, class_name: 'Spree::UserAccount', foreign_key: :user_id, primary_key: :id
  has_many :accounts, through: :user_accounts, source: :account
  has_many :vendors, through: :accounts, source: :vendor
  has_many :contacts

  belongs_to :permission_group, class_name: 'Spree::PermissionGroup', foreign_key: :permission_group_id, primary_key: :id

  after_create :find_default_permission_group
  after_save :link_contacts_to_user, if: :email_changed?
  after_save :remove_user_accounts, if: :company_id_changed?
  after_commit :assign_contact_accounts, on: :update

  def self.find_by_email(email_address)
    where('email ilike ?', email_address).first
  end

  def account_ids=(arr)
    super(arr.reject(&:blank?).map(&:to_i))
  end
  def customer_accounts
    self.accounts.where(vendor_id: self.company_id)
  end
  def vendor_accounts
    self.accounts.where(customer_id: self.company_id)
  end
  def invited_contacts
    contacts.where.not(invited_at: nil)
  end

  def display_vendor_account_names
    names = vendor_accounts.map(&:vendor_account_name)
    case names.count
    when 0
      ''
    when 1
      names.first
    when self.company.vendor_accounts.count
      'All'
    else
      'Multiple'
    end
  end

  attr_default :comms_settings do
    {
      "email_order_confirmed" => false,
      "email_order_approved" => false,
      "email_order_revised" => false,
      "email_order_received" => false,
      "email_order_canceled" => false,
      "email_order_review" => false,
      "email_order_finalized" => false,
      "email_daily_summary" => false,
      "email_daily_shipping_reminder" => false,
      "email_so_edited" => false,
      "email_so_create_error" => false,
      "email_so_reminder" => false,
      "email_discontinued_products" => false,
      "email_summary_send_time" => '10:00PM',
      "email_low_stock" => false,
      "stop_all_emails" => false
    }
  end

  attr_default :permissions do
    Spree::Permission.owner_permissions
  end

  def name
    "#{firstname} #{lastname}"
  end

  def is_vendor?
    self.has_spree_role?('vendor')
  end

  def is_customer?
    self.has_spree_role?('customer')
  end

  def is_admin?
    self.has_spree_role?('admin')
  end

  # convert string to boolean. hstore only stores strings
  def view_images?
    self.view_images
  end

  def view_images
    ActiveRecord::Type::Boolean.new.type_cast_from_database(
      settings.fetch('view_images', true)
    ) rescue true
  end

  def view_images=(value)
    settings['view_images']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  #########################################################
  #######      COMMMUNICATION SETTING METHODS      ########
  #########################################################

  # 1 - order confirmation read and set methods
  def order_confirmed
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_order_confirmed'])
  end
  def order_confirmed=(value)
    comms_settings['email_order_confirmed']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def order_approved
    comms_settings['email_order_approved'].to_bool rescue false
  end
  def order_approved=(value)
    comms_settings['email_order_approved'] = value.to_bool
  end

  # 2 - order revision read and set methods
  def order_revised
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_order_revised'])
  end
  def order_revised=(value)
    comms_settings['email_order_revised']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 3 - order received read and set methods
  def order_received
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_order_received'])
  end
  def order_received=(value)
    comms_settings['email_order_received']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 4 - order canceled read and set methods
  def order_canceled
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_order_canceled'])
  end
  def order_canceled=(value)
    comms_settings['email_order_canceled']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 5 - order in review read and set methods
  def order_review
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_order_review'])
  end
  def order_review=(value)
    comms_settings['email_order_review']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 6 - order finalized read and set methods
  def order_finalized
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_order_finalized'])
  end
  def order_finalized=(value)
    comms_settings['email_order_finalized']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 7 - daily summary read and set methods
  def daily_summary
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_daily_summary'])
  end
  def daily_summary=(value)
    comms_settings['email_daily_summary']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def low_stock
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_low_stock'])
  end
  def low_stock=(value)
    comms_settings['email_low_stock']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def daily_shipping_reminder
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_daily_shipping_reminder'])
  end
  def daily_shipping_reminder=(value)
    comms_settings['email_daily_shipping_reminder']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 8 - standing order edited  read and set methods
  def so_edited
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_so_edited'])
  end
  def so_edited=(value)
    comms_settings['email_so_edited']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def so_reminder
    comms_settings.fetch('email_so_reminder', true)
  end
  def so_reminder=(value)
    comms_settings['email_so_reminder']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 9 - error create order from standing order  read and set methods
  def so_create_error
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_so_create_error'])
  end
  def so_create_error=(value)
    comms_settings['email_so_create_error']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 10 - discontinued_products  read and set methods
  def discontinued_products
    ActiveRecord::Type::Boolean.new.type_cast_from_database(comms_settings['email_discontinued_products'])
  end
  def discontinued_products=(value)
    comms_settings['email_discontinued_products']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  # 11 - daily summary time  read and set methods
  def summary_send_time
    comms_settings['email_summary_send_time']
  end
  def summary_send_time=(value)
    comms_settings['email_summary_send_time']=value
  end

  # 12 - stop all emails  read and set methods
  def stop_all_emails
    comms_settings.fetch('email_stop_all_emails', false)
  end
  def stop_all_emails=(value)
    comms_settings['email_stop_all_emails']=ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  #########################################################
  #########################################################
  #######    END COMMMUNICATION SETTING METHODS     ########
  #########################################################

  def find_default_permission_group
    default = self.company.present? ? self.company.permission_groups.where(is_default: true).first : nil
    if default.present?
      self.permission_group_id = default.id
      self.permissions = default.permissions
      self.save
    else
      self.give_owner_access
    end
  end

  def give_staff_access
    self.permission_group = Spree::PermissionGroup.where(company_id: nil, name: "Staff Access").first
    if self.permission_group
      self.permissions = self.permission_group.permissions
    else
      self.permissions = Spree::Permission.staff_permissions
    end
    self.save
  end

  def give_owner_access
    self.permission_group = Spree::PermissionGroup.where(company_id: nil, name: "Owner Access").first
    if self.permission_group
      self.permissions = self.permission_group.permissions
    else
      self.permissions = Spree::Permission.owner_permissions
    end
    self.save
  end

  def give_all_order_access
    self.permissions['order']['basic_options'] = 2
    self.permissions['order']['edit_line_item'] = true
    self.permissions['order']['approve_ship_receive'] = true
    self..permission_order_manual_adjustment = true
    self.save
  end

  def default_permission_value(permission, base)
    permission_val = nil
    if self.permission_group
      if base
        permission_val = self.permission_group.permissions.fetch(base,{}).fetch(permission.to_s, nil)
      else
        permission_val = self.permission_group.permissions.fetch(permission.to_s, nil)
      end
    end
    if permission_val.nil?
      if base
        permission_val = Spree::Permission.staff_permissions.fetch(base,{}).fetch(permission.to_s, nil)
      else
        permission_val = Spree::Permission.staff_permissions.fetch(permission.to_s, nil)
      end
    end

    permission_val
  end

  def can_read?(permission, base = nil)
    if base
      permission_val = self.permissions.fetch(base,{}).fetch(permission.to_s, nil)
    else
      permission_val = self.permissions.fetch(permission.to_s, nil)
    end
    permission_val ||= self.default_permission_value(permission, base)

    return permission_val if permission_val.is_a? BooleanToBoolean
    permission_val.to_i >= Spree::Permission::Permissions['read']
  end
  def cannot_read?(permission, base = nil)
    !can_read?(permission, base)
  end

  def can_write?(permission, base = nil)
    if base
      permission_val = self.permissions.fetch(base,{}).fetch(permission.to_s, 0)
    else
      permission_val = self.permissions.fetch(permission.to_s, 0)
    end
    permission_val ||= self.default_permission_value(permission, base)

    return permission_val if permission_val.is_a? BooleanToBoolean
    permission_val.to_i >= Spree::Permission::Permissions['write']
  end
  def cannot_write?(permission, base = nil)
    !can_write?(permission, base)
  end

  Spree::Permission.staff_permissions.keys.each do |k|
    default = Spree::Permission.staff_permissions
    if default[k].is_a? Hash
      default[k].keys.each do |kk|
        define_method "permission_#{k}_#{kk}" do
          perm_group = self.permission_group
          self.permissions[k] = {} unless self.permissions[k].is_a? Hash
          if self.permissions[k][kk].nil?
            if perm_group
              perm_group.permissions.fetch(k, {}).fetch(kk, nil) || default[k][kk]
            else
              default[k][kk]
            end
          else
            self.permissions[k][kk]
          end
        end
        define_method "permission_#{k}_#{kk}=" do |value|
          permissions[k] ||= {}
          permissions[k][kk] = value.to_hash if default[k][kk].is_a?(Hash)
          permissions[k][kk] = value.to_s if default[k][kk].is_a?(String)
          permissions[k][kk] = value.to_i if default[k][kk].is_a?(Integer)
          permissions[k][kk] = value.to_bool if default[k][kk].is_a?(BooleanToBoolean)
        end
      end
    else
      define_method "permission_#{k}" do
        if self.permissions[k].nil?
          if perm_group
            perm_group.permissions.fetch(k, nil) || default[k]
          else
            default[k]
          end
        else
          self.permissions[k]
        end
      end
      define_method "permission_#{k}=" do |value|
        permissions[k] = value.to_hash if default[k].is_a?(Hash)
        permissions[k] = value.to_s if default[k].is_a?(String)
        permissions[k] = value.to_i if default[k].is_a?(Integer)
        permissions[k] = value.to_bool if default[k].is_a?(BooleanToBoolean)
      end
    end
  end

  def has_access_to_account(account)
    self.accounts.where(id: account.try(:id)).present?
  end

  def link_contacts_to_user
    self.contacts.update_all(email: self.email)
    Spree::Contact.where('email ilike ?', self.email).update_all(user_id: self.id)
  end

  def assign_contact_accounts
    acc_ids = user_accounts.pluck(:account_id)

    if acc_ids.empty?
      Spree::ContactAccount.where(contact_id: self.reload.invited_contacts.ids).delete_all
    else
      self.reload.invited_contacts.each do |contact|
        contact.contact_accounts.where.not(account_id: acc_ids).destroy_all
        #ActiveRecord will handle creating records and duplicate ids!
        contact.account_ids += contact.company.customer_accounts.where(id: acc_ids).ids
      end
    end
  end

  private

  def remove_user_accounts
    user_accounts.where.not(account_id: company.vendor_accounts.ids).destroy_all
    reload
  end

end
