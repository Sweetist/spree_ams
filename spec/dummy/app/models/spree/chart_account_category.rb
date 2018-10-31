# == Schema Information
#
# Table name: spree_chart_account_categories
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

module Spree
  class ChartAccountCategory < Spree::Base
    include Spree::Integrationable
    self.whitelisted_ransackable_attributes = %w[name]

    attr_accessor :filter_vendor_id

    has_many :chart_accounts, class_name: 'Spree::ChartAccount', foreign_key: :chart_account_category_id, primary_key: :id

    def vendors_chart_accounts
      self.chart_accounts.where(vendor_id: self.filter_vendor_id).order('fully_qualified_name asc')
    end
  end
end
