Sweet::Application.config.x.default_country_iso = 'US'
Sweet::Application.config.x.admin_time_zone = 'EST'
Sweet::Application.config.x.date_formats = ['mm/dd/yyyy', 'dd/mm/yyyy']
Sweet::Application.config.x.weight_units = [['oz','oz'],['lb', 'lb'],['gm','gm'],['kg','kg']]
Sweet::Application.config.x.dimension_units = [['in', 'in'],['cm','cm']]
Sweet::Application.config.x.max_option_types = 4
Sweet::Application.config.x.adjust_inventory_after_ship = true
Sweet::Application.config.x.integration_rake_frequency = 10 #number of minutes between polling rake task

Sweet::Application.config.x.payment_methods = [
  # Spree::BillingIntegration::Skrill::QuickCheckout,
  Spree::Gateway::AuthorizeNet,
  Spree::Gateway::AuthorizeNetCim,
  # Spree::Gateway::BalancedGateway,
  # Spree::Gateway::Banwire,
  # Spree::Gateway::Beanstream,
  # Spree::Gateway::BraintreeGateway,
  # Spree::Gateway::CardSave,
  # Spree::Gateway::CyberSource,
  # Spree::Gateway::Check,
  Spree::PaymentMethod::Check,
  Spree::PaymentMethod::Cash,
  Spree::PaymentMethod::Other,
  # Spree::Gateway::DataCash,
  # Spree::Gateway::Eway,
  # Spree::Gateway::Maxipago,
  # Spree::Gateway::Migs,
  # Spree::Gateway::Moneris,
  # Spree::Gateway::PayJunction,
  # Spree::Gateway::PayPalGateway,
  # Spree::Gateway::PayflowPro,
  # Spree::Gateway::Paymill,
  # Spree::Gateway::PinGateway,
  # Spree::Gateway::SagePay,
  # Spree::Gateway::SecurePayAU,
  # Spree::Gateway::SpreedlyCoreGateway,
  Spree::Gateway::StripeGateway,
  # Spree::Gateway::UsaEpayTransaction,
  # Spree::Gateway::Worldpay
]

Sweet::Application.config.x.basic_payment_methods = [
  Spree::PaymentMethod::Check,
  Spree::PaymentMethod::Cash,
  Spree::PaymentMethod::Other
]
