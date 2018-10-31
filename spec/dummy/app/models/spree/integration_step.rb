class Spree::IntegrationStep < ActiveRecord::Base
  belongs_to :integration_action, class_name: 'Spree::IntegrationAction', foreign_key: :integration_action_id, primary_key: :id
  belongs_to :parent, class_name: 'Spree::IntegrationStep', foreign_key: :parent_id, primary_key: :id
  has_many :sub_steps, class_name: 'Spree::IntegrationStep', foreign_key: :parent_id, primary_key: :id
  scope :incomplete, -> { where(status: 0) }

  def make_current
    Spree::IntegrationStep.where(
      integration_action_id: self.integration_action_id
    ).update_all(is_current: false)

    self.is_current = true
    self.save!
  end

end
