Spree::Page.class_eval do
  acts_as_list
  belongs_to :company, class_name: 'Spree::Company', foreign_key: :company_id, primary_key: :id
end
