Spree::Gateway::AuthorizeNet.class_eval do
  def preference_label(key)
    case key
    when :login
      Spree.t(:api_login_id, scope: :gateway_preferences)
    when :password
      Spree.t(:transaction_key, scope: :gateway_preferences)
    when :server
      Spree.t(:server, scope: [:gateway_preferences, :authorize_net])
    else
      super
    end
  end
end
