Spree::Promotion::Rules::ItemTotal.class_eval do

  #default spree incorrectly checks both ineligible_message_max and min based on
  # gte. The operator_max should be checked against < or <=
  def ineligible_message_max
    if preferred_operator_max == 'lt'
      eligibility_error_message(:item_total_more_than_or_equal, amount: formatted_amount_max)
    else
      eligibility_error_message(:item_total_more_than, amount: formatted_amount_max)
    end
  end

end
