# == Schema Information
#
# Table name: spree_chart_accounts
#
#  id                        :integer          not null, primary key
#  name                      :string           not null
#  chart_account_category_id :integer
#  vendor_id                 :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

module Spree
  class ChartAccount < Spree::Base
    include Spree::Integrationable

    validates :name, presence: true, uniqueness: { scope: [:parent_id, :vendor_id] }
    validate :valid_parent

    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    belongs_to :chart_account_category, class_name: 'Spree::ChartAccountCategory', foreign_key: :chart_account_category_id, primary_key: :id
    has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
    belongs_to :parent_account, class_name: "Spree::ChartAccount", foreign_key: :parent_id, primary_key: :id

    self.whitelisted_ransackable_attributes = %w[name fully_qualified_name]
    self.whitelisted_ransackable_associations = %w[chart_account_category]

    before_save :set_fully_qualified_name

    after_commit :update_children_fully_qualified_name

    def child_accounts
      Spree::ChartAccount.where(parent_id: id)
    end



    def name_for_integration
      "#{self.chart_account_category.try(:name)} - #{self.name}"
    end

    protected

    def set_fully_qualified_name
      if self.parent_account
        self.fully_qualified_name = "#{self.parent_account.fully_qualified_name}:#{self.name}"
        self.chart_account_category = self.parent_account.chart_account_category
      else
        self.fully_qualified_name = "#{self.name}"
      end

      self.fully_qualified_name
    end

    def update_children_fully_qualified_name
      self.child_accounts.each do |c|
        c.set_fully_qualified_name
        c.save
      end
    end

    private

    def valid_parent
      valid = true
      if parent_id.present? && parent_id == self.id
        self.errors.add(:parent_account, "cannot be the same as account.")
        valid = false
      end

      if parent_account && parent_account.chart_account_category_id != chart_account_category_id
        self.errors.add(:chart_account_category_id, 'must be the same as the parent account')
        valid = false
      end

      valid
    end

  end
end
