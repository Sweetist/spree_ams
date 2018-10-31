Spree::ShippingRate.class_eval do
  def display_price
      price = display_base_price.to_s
      if tax_rate
        tax_amount = calculate_tax_amount
        if tax_amount != 0
          if tax_rate.included_in_price?
            if tax_amount > 0
              amount = "#{display_tax_amount(tax_amount)} #{tax_rate.name}"
            else
              amount = "#{display_tax_amount(tax_amount*-1)} #{tax_rate.name}"
            end
            price += " (#{Spree.t(:incl)} #{amount})"
          else
            amount = "#{display_tax_amount(tax_amount)} #{tax_rate.name}"
            price += " (+ #{amount})"
          end
        end
      end
      price
    end

end
