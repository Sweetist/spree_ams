class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

  require 'csv'

  Spree::PermittedAttributes.source_attributes << :account_id
  Spree::PermittedAttributes.user_attributes << :company_id
  Spree::PermittedAttributes.user_attributes << :firstname
  Spree::PermittedAttributes.user_attributes << :lastname
  Spree::PermittedAttributes.user_attributes << :customer_admin
  Spree::PermittedAttributes.variant_attributes << :pack_size
  Spree::PermittedAttributes.variant_attributes << :lead_time
  Spree::PermittedAttributes.product_attributes << :vendor_id
  Spree::PermittedAttributes.line_item_attributes << :item_name
  Spree::PermittedAttributes.line_item_attributes << :pack_size
  Spree::PermittedAttributes.line_item_attributes << :lot_number
  Spree::PermittedAttributes.line_item_attributes << :txn_class_id
  Spree::PermittedAttributes.line_item_attributes << :position
  Spree::PermittedAttributes.line_item_attributes << :text_option
  Spree::PermittedAttributes.taxonomy_attributes << :vendor_id
  Spree::PermittedAttributes.payment_attributes << :memo
  Spree::PermittedAttributes.payment_attributes << :txn_id
  Spree::PermittedAttributes.source_attributes << :zip

  include Spree::BaseHelper
  include Spree::Core::ControllerHelpers
  include Spree::Core::ControllerHelpers::Store
  include ApplicationHelper
  helper Spree::Core::Engine.helpers

  before_action :set_paper_trail_whodunnit

  def user_for_paper_trail
    current_spree_user.try(:email)
  end
  def info_for_paper_trail
    {
      controller: params[:controller],
      action: params[:action],
      commit: params[:commit],
      params: request.filtered_parameters,
      transaction_group_id: "#{Time.current.to_i}_#{SecureRandom.hex(8)}"
    }
  end
end
