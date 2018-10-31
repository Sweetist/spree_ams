# == Schema Information
#
# Table name: spree_permission_groups
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  company_id  :integer
#  permissions :jsonb
#  is_default  :boolean          default(FALSE)
#

module Spree
  class PermissionGroup < Spree::Base
    belongs_to :company, class_name: 'Spree::Company', foreign_key: :company_id, primary_key: :id
    has_many :users, class_name: 'Spree::User', foreign_key: :permission_group_id, primary_key: :id

    validates :name, presence: true

    after_save :ensure_one_default
    after_save :update_all_users

    attr_default :permissions do
      Spree::Permission.owner_permissions
    end

    def ensure_one_default
      if self.is_default? && self.company
        self.company.permission_groups.where.not(id: self.try(:id)).update_all(is_default: false)
      end
    end

    def update_all_users
      self.users.update_all(permissions: self.permissions)
    end

    Spree::Permission.owner_permissions.keys.each do |k|
      default = Spree::Permission.owner_permissions
      if default[k].is_a? Hash
        default[k].keys.each do |kk|
          define_method "permission_#{k}_#{kk}" do
            self.permissions[k] = {} unless self.permissions[k].is_a? Hash
            (self.permissions[k][kk].nil? ? default[k][kk] : self.permissions[k][kk])
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
          (self.permissions[k].nil? ? default[k] : self.permissions[k])
        end
        define_method "permission_#{k}=" do |value|
          permissions[k] = value.to_hash if default[k].is_a?(Hash)
          permissions[k] = value.to_s if default[k].is_a?(String)
          permissions[k] = value.to_i if default[k].is_a?(Integer)
          permissions[k] = value.to_bool if default[k].is_a?(BooleanToBoolean)
        end
      end
    end

    def default_permissions
      Spree::Permission.owner_permissions
    end

    def ensure_up_to_date
      defaults = default_permissions
      defaults.each do |k, v|
        if !permissions.key?(k)
          permissions[k] = default_permissions[k]
        elsif v.is_a? Hash
          permissions[k] = {} unless permissions[k].is_a? Hash
          v.each do |kk, vv|
            permissions[k][kk] = vv if !permissions[k].key?(kk)
          end
        end
      end

      self.save
    end
  end
end
