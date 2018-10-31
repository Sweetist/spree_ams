Spree::Promotion::Rules::FirstOrder.class_eval do

  def eligible?(order, options = {})
    @user = order.try(:user) || options[:user]
    @email = order.email

    if order.account
      if !completed_orders(order.account).blank? && completed_orders(order.account).first != order
        eligibility_errors.add(:base, eligibility_error_message(:not_first_order))
      end
    else
      eligibility_errors.add(:base, eligibility_error_message(:no_user_or_email_specified))
    end

    eligibility_errors.empty?
  end

  private
  def completed_orders(account)
    account.orders.complete
  end
end
