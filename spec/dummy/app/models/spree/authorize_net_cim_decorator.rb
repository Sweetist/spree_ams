Spree::Gateway::AuthorizeNetCim.class_eval do
  def preference_label(key)
    case key
    when :login
      Spree.t(:api_login_id, scope: :gateway_preferences)
    when :password
      Spree.t(:transaction_key, scope: :gateway_preferences)
    when :server
      Spree.t(:server, scope: [:gateway_preferences, :authorize_net_cim])
    else
      super
    end
  end

  def update_payment_profile(payment)
    if payment.source.has_payment_profile?
      if hash = get_payment_profile(payment)
        hash[:bill_to] = generate_address_hash(payment.try(:account).try(:bill_address))
        if hash[:payment][:credit_card]
          # activemerchant expects a credit card object with 'number', 'year', 'month', and 'verification_value?' defined
          payment.source.define_singleton_method(:number) { "XXXXXXXXX#{payment.source.last_digits}" }
          hash[:payment][:credit_card] = payment.source
        end
        cim_gateway.update_customer_payment_profile({
          customer_profile_id: payment.source.gateway_customer_profile_id,
          payment_profile: hash
        })
      end
    end
  end

  private

  def transaction_options(gateway_options = {})
    {}
  end

  def options_for_create_customer_profile(payment)
    if payment.is_a? Spree::CreditCard
      info = { bill_to: generate_address_hash(payment.address),
               payment: { credit_card: payment } }
    else
      info = { bill_to: generate_address_hash(payment.try(:account).try(:bill_address)),
               payment: { credit_card: payment.source } }
    end
    validation_mode = preferred_validate_on_profile_create ? preferred_server.to_sym : :none

    { profile: { merchant_customer_id: "#{Time.current.to_f}",
                 ship_to_list: generate_address_hash(payment.try(:account).try(:default_ship_address)),
                 email: payment.try(:account).try(:email),
                 payment_profiles: info },
      validation_mode: validation_mode }
  end
end
