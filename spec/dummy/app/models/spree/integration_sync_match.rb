# == Schema Information
#
# Table name: spree_integration_sync_matches
#
#  id                        :integer          not null, primary key
#  integration_syncable_id   :integer         # id of the object in SWEET
#  integration_syncable_type :string          # class of object in SWEET
#  integration_item_id       :integer
#  sync_id                   :string          # id of object in other database
#  sync_type                 :string
#  sync_alt_id               :string
#  synced_at                 :datetime
#

class Spree::IntegrationSyncMatch < ActiveRecord::Base
  belongs_to :integration_syncable, polymorphic: true
  belongs_to :integration_item

  before_save :set_synced_at

  def sync_object_is_unchanged?(time)
    self.sync_object_updated_at == time
  end

  def sync_object_is_changed?(time)
    self.sync_object_updated_at != time
  end

  private

  def set_synced_at
    unless sync_id.blank? || integration_syncable_id.blank?
      self.synced_at = Time.current
    end
  end

end
