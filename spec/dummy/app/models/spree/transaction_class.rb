class Spree::TransactionClass < ActiveRecord::Base
  include Spree::Integrationable

  validates :name, presence: true, uniqueness: { scope: [:parent_id, :vendor_id] }

  has_many :line_items, class_name: "Spree::LineItem", foreign_key: :txn_class_id, primary_key: :id
  has_many :orders, class_name: "Spree::Order", foreign_key: :txn_class_id, primary_key: :id
  has_many :standing_orders, class_name: "Spree::StandingOrder", foreign_key: :txn_class_id, primary_key: :id
  has_many :standing_line_items, class_name: "Spree::StandingLineItem", foreign_key: :txn_class_id, primary_key: :id
  has_many :accounts, class_name: "Spree::Account", foreign_key: :default_txn_class_id, primary_key: :id
  has_many :variants, class_name: "Spree::Variant", foreign_key: :txn_class_id, primary_key: :id

  belongs_to :vendor, class_name: "Spree::Company", foreign_key: :vendor_id, primary_key: :id
  belongs_to :parent_class, class_name: "Spree::TransactionClass", foreign_key: :parent_id, primary_key: :id

  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy

  before_save :set_fully_qualified_name

  after_commit :update_children_fully_qualified_name

  def child_classes
    Spree::TransactionClass.where(parent_id: id)
  end

  def set_fully_qualified_name
    if self.parent_class
      self.fully_qualified_name = "#{self.parent_class.fully_qualified_name}:#{self.name}"
    else
      self.fully_qualified_name = "#{self.name}"
    end

    self.fully_qualified_name
  end

  def update_children_fully_qualified_name
    self.child_classes.each do
      |c| c.set_fully_qualified_name
      c.save
    end
  end
  
  def name_for_integration
    "Class #{fully_qualified_name}"
  end
end
