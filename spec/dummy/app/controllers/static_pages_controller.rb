class StaticPagesController < ApplicationController
  layout 'session'

  before_action :require_not_logged_in

  def root
    flash[:error] = params[:error] if params[:error]
    session[:order_id] = nil
  end

  private

  def require_not_logged_in
    if current_spree_user
      if spree_current_user.is_vendor?
        redirect_to '/manage'
      elsif spree_current_user.is_customer?
        if session[:vendor_id].present?
          vendor = current_spree_user.vendors.find_by_id(session[:vendor_id])
        else
          vendor = current_spree_user.vendors.first
        end
        if vendor.nil?
          redirect_to spree.orders_path
        else
          redirect_to spree.vendor_products_path(vendor)
        end
      elsif spree_current_user.is_admin?
        redirect_to '/admin'
      end
    end
  end

end
