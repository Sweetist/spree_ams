module Spree
  class OrderedPart < ActiveRecord::Base
    belongs_to :part_variant, class_name: 'Spree::Variant',
                              foreign_key: :part_variant_id, primary_key: :id
    belongs_to :line_item, class_name: 'Spree::LineItem',
                           foreign_key: :line_item_id, primary_key: :id

    validates :part_variant, :line_item, :part_qty, :quantity, presence: true
  end
end
