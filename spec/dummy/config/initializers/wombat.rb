Spree::Wombat::Config.configure do |config|
  if Rails.env.development?
    config.push_url = 'http://localhost:9292/cangaroo/endpoint'
    config.connection_token = 'secrettoken'
    config.connection_id = 'secretkey'
  elsif !Rails.env.test?
    config.push_url = ENV['CANGAROO_ENDPOINT']
    config.connection_token = ENV['CANGAROO_SECRET_TOKEN']
    config.connection_id = ENV['CANGAROO_SECRET_KEY']
  end

  config.push_objects = ['Spree::Order',
                         'Spree::Product',
                         'Spree::StockMovement',
                         'Spree::StockItem']
  config.payload_builder = {
    'Spree::Order' => { serializer: 'Spree::Wombat::OrderSerializer',
                        root: 'orders' },
    'Spree::Product' => { serializer: 'Spree::Wombat::ProductSerializer',
                          root: 'products' },
    'Spree::StockMovement' => { serializer: 'Spree::Wombat::StockMovementSerializer',
                                root: 'inventories' },
    'Spree::StockItem' => { serializer: 'Spree::Wombat::Spree::StockItemSerializer',
                            root: 'inventories' }
  }
end
