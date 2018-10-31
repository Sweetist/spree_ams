Spree::Role.class_eval do
  has_many :legacy_vendors, through: :users, foreign_key: :vendor_lid
  has_many :legacy_customers, through: :users, foreign_key: :customer_lid
end
