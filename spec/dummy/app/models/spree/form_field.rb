module Spree
  class FormField < Spree::Base
    belongs_to :form, class_name: 'Spree::Form', foreign_key: :form_id, primary_key: :id

    FIELD_TYPES = %w[text_field text_area number_field email_field].freeze
    FIELD_VALUE_TYPES = %w[string number boolean]
    validates :label, :field_type, presence: true
    validates :field_type, inclusion: { in: FIELD_TYPES,
      message: "%{value} is not a valid field type" }

  end
end
