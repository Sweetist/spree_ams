module Spree
  class Form < Spree::Base
    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    has_many :fields, class_name: 'Spree::FormField', foreign_key: :form_id, primary_key: :id, dependent: :destroy
    scope :active, -> { where(active: true) }
    scope :request_access, -> { where(form_type: 'request_account') }

    FORM_TYPES = %w[request_account].freeze
    validates :name, :vendor_id, :fields, presence: true
    validates :name, uniqueness: {scope: :vendor_id}
    validates :form_type, inclusion: { in: FORM_TYPES,
      message: "%{value} is not a valid field type" }

    validate :valid_column_spans

    accepts_nested_attributes_for :fields, allow_destroy: true

    def valid_column_spans
      return true if fields.none?{|field| field.num_columns > num_columns }

      self.errors.add(:field, "column span cannot exceed the number of columns on the form.")
      false
    end
  end
end
