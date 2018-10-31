class Spree::Integration

  def self.available_vendors_integrations(vendor)
    return unless vendor
    [
      # {
      #   integration_key: 'qbs',
      #   name: 'QuickBooks Desktop',
      #   visible: true,
      #   auto_create: true,
      #   description: 'A connection to Quickbooks Desktop will allow you to seamlessly send order, product, and customer data to Quickbooks.',
      #   image: 'spree/manage/img/qb-ico.png',
      #   multi: false,
      #   integrations: vendor.integration_items.where(integration_key: 'qbs')
      # },
      {
        integration_key: 'qbd',
        name: 'QuickBooks Desktop',
        visible: true, #Rails.env == 'development', # Enable only in development environment
        auto_create: true,
        integration_type: :accounting,
        should_timeout: false, #integration sets everything enqueued to processing when started, so everything will time out if this is on
        description: 'A connection to Quickbooks Desktop will allow you to seamlessly send order, product, and customer data to Quickbooks.',
        image: 'spree/manage/img/qb-ico.png',
        multi: false,
        integrations: vendor.integration_items.where(integration_key: 'qbd')
      },
      {
        integration_key: 'qbo',
        name: 'QuickBooks Online',
        visible: true,
        auto_create: true,
        integration_type: :accounting,
        description: 'A connection to Quickbooks Online will allow you to seamlessly send order, product, and customer data to Quickbooks.',
        image: 'spree/manage/img/qb-ico.png',
        multi: false,
        integrations: vendor.integration_items.where(integration_key: 'qbo')
      },
      {
        integration_key: 'sweetist',
        name: 'Sweetist',
        visible: true,
        auto_create: true,
        integration_type: :sweetist,
        description: 'Sweetist is the online bakery marketplace. Partners on Sweetist receive marketing and customer support services and pay nothing upfront.',
        image: 'spree/manage/img/sweetist-logo-cityscape-only-nobg-square-64x64px.png',
        multi: false,
        integrations: vendor.integration_items.where(integration_key: 'sweetist')
      },
      {
        integration_key: 'shipstation',
        name: 'ShipStation',
        visible: true,
        auto_create: true,
        integration_type: :shipping,
        description: 'A connection to ShipStation will allow ShipStation to pull order data and return accurate shipping rates to your orders in Sweet.',
        image: 'spree/manage/img/shipstation.png',
        multi: false,
        integrations: vendor.integration_items.where(integration_key: 'shipstation')
      },
      {
        integration_key: 'shipping_easy',
        name: 'ShippingEasy',
        visible: true,
        auto_create: true,
        integration_type: :shipping,
        description: 'A connection to ShippingEasy.com will allow ShippingEasy to pull order data and return accurate shipping rates to your orders in Sweet.',
        image: 'spree/manage/img/shipping_easy.jpg',
        multi: false,
        integrations: vendor.integration_items.where(integration_key: 'shipping_easy')
      },
      {
        integration_key: 'shopify',
        name: 'Shopify',
        visible: true,
        auto_create: true,
        integration_type: :sales_channel,
        should_timeout: true, # set fail on action while timeout off
        description: 'A connection to Shopify.com will allow Shopify to pull order data and return accurate shipping rates to your orders in Sweet.',
        image: 'spree/manage/img/shopify.png',
        multi: false,
        integrations: vendor.integration_items.where(integration_key: 'shopify')
      }
    ]
  end
end
