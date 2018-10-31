class Spree::Subscription
  # Subscription = {'sweetist' => 0, 'starter' => 1, 'plus' => 2, 'platinum' => 3, 'enterprise' => 4 }
  Subscriptions = {
    'sweetist' => {
      'booleans' => {
        'advanced_user_rights' => false,
        'basic_user_rights' => false,
        'unlimited_customer_accounts' => false,
        'custom_domain' => false,
        'inventory' => false,
        'payments' => false,
        'permission_groups' => false,
        'assemblies' => false,
        'lot_tracking' => false,
        'api' => false,
        'integrations' => false
      },
        'limits' => {
        'user_limit' => 1,
        'order_history_limit' => 100,
        'orders_per_month' => 100,
        'standing_order_limit' => 5,
        'integration_limit' => 0,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => 1,
        'relationships' => 50
      }
    },
    'starter' => {
      'booleans' => {
        'advanced_user_rights' => false,
        'basic_user_rights' => true,
        'unlimited_customer_accounts' => false,
        'custom_domain' => false,
        'inventory' => true,
        'payments' => false,
        'permission_groups' => false,
        'assemblies' => false,
        'lot_tracking' => false,
        'api' => false,
        'integrations' => true
      },
        'limits' => {
        'user_limit' => 2,
        'order_history_limit' => nil,
        'orders_per_month' => 200,
        'standing_order_limit' => nil,
        'integration_limit' => 2,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => 1,
        'relationships' => nil
      }
    },
    'starter_legacy' => {
      'booleans' => {
        'advanced_user_rights' => false,
        'basic_user_rights' => false,
        'unlimited_customer_accounts' => false,
        'custom_domain' => false,
        'inventory' => false,
        'payments' => false,
        'permission_groups' => false,
        'assemblies' => false,
        'lot_tracking' => false,
        'api' => false,
        'integrations' => true
      },
        'limits' => {
        'user_limit' => 1,
        'order_history_limit' => 100,
        'orders_per_month' => nil,
        'standing_order_limit' => 5,
        'integration_limit' => 1,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => nil,
        'relationships' => nil
      }
    },
    'plus' => {
      'booleans' => {
        'advanced_user_rights' => false,
        'basic_user_rights' => true,
        'unlimited_customer_accounts' => false,
        'custom_domain' => false,
        'inventory' => true,
        'payments' => true,
        'permission_groups' => true,
        'assemblies' => true,
        'lot_tracking' => false,
        'api' => false,
        'integrations' => true
      },
        'limits' => {
        'user_limit' => 4,
        'order_history_limit' => nil,
        'orders_per_month' => 500,
        'standing_order_limit' => nil,
        'integration_limit' => 5,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => nil,
        'relationships' => nil
      }
    },
    'plus_legacy' => {
      'booleans' => {
        'advanced_user_rights' => false,
        'basic_user_rights' => true,
        'unlimited_customer_accounts' => false,
        'custom_domain' => false,
        'inventory' => false,
        'payments' => false,
        'permission_groups' => true,
        'assemblies' => false,
        'lot_tracking' => false,
        'api' => false,
        'integrations' => true
      },
        'limits' => {
        'user_limit' => 2,
        'order_history_limit' => nil,
        'orders_per_month' => nil,
        'standing_order_limit' => nil,
        'integration_limit' => 5,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => nil,
        'relationships' => nil
        }
    },
    'plus_lot_tracking' => {
      'booleans' => {
        'advanced_user_rights' => false,
        'basic_user_rights' => true,
        'unlimited_customer_accounts' => false,
        'custom_domain' => false,
        'inventory' => true,
        'payments' => true,
        'permission_groups' => true,
        'assemblies' => true,
        'lot_tracking' => true,
        'api' => false,
        'integrations' => true
      },
        'limits' => {
        'user_limit' => 4,
        'order_history_limit' => nil,
        'orders_per_month' => 500,
        'standing_order_limit' => nil,
        'integration_limit' => 5,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => nil,
        'relationships' => nil
      }
    },
    'platinum' => {
      'booleans' => {
        'advanced_user_rights' => true,
        'basic_user_rights' => true,
        'unlimited_customer_accounts' => false,
        'custom_domain' => true,
        'inventory' => true,
        'payments' => true,
        'permission_groups' => true,
        'assemblies' => true,
        'lot_tracking' => true,
        'api' => false,
        'integrations' => true
      },
        'limits' => {
        'user_limit' => 6,
        'order_history_limit' => nil,
        'orders_per_month' => 1500,
        'standing_order_limit' => nil,
        'integration_limit' => nil,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => nil,
        'relationships' => nil
      }
    },
    'platinum_legacy' => {
      'booleans' => {
        'advanced_user_rights' => true,
        'basic_user_rights' => true,
        'unlimited_customer_accounts' => false,
        'custom_domain' => true,
        'inventory' => true,
        'payments' => true,
        'permission_groups' => true,
        'assemblies' => true,
        'lot_tracking' => true,
        'api' => true,
        'integrations' => true
      },
        'limits' => {
        'user_limit' => 2,
        'order_history_limit' => nil,
        'orders_per_month' => nil,
        'standing_order_limit' => nil,
        'integration_limit' => nil,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => nil,
        'relationships' => nil
      }
    },
    'enterprise' => {
      'booleans' => {
        'advanced_user_rights' => true,
        'basic_user_rights' => true,
        'unlimited_customer_accounts' => false,
        'custom_domain' => true,
        'inventory' => true,
        'payments' => true,
        'permission_groups' => true,
        'assemblies' => true,
        'lot_tracking' => true,
        'api' => true,
        'integrations' => true
      },
      'limits' => {
        'user_limit' => nil,
        'order_history_limit' => nil,
        'orders_per_month' => nil,
        'standing_order_limit' => nil,
        'integration_limit' => nil,
        'purchase_order_history_limit' => nil,
        'products' => nil,
        'stock_locations' => nil,
        'relationships' => nil
      }
    }
  }

  Additionals = {
    'sweetist' => {
      'booleans' => {},
      'limits' => {}
    },
    'starter' => {
      'booleans' => {
        'custom_domain' => 25
      },
      'limits' => {}
    },
    'plus' => {
      'booleans' => {
        'custom_domain' => 25,
        'lot_tracking' => 49
      },
      'limits' => {}
    },
    'platinum' => {
      'booleans' => {
        'custom_domain' => 25
      },
      'limits' => {}
    },
    'enterprise' => {
      'booleans' => {},
      'limits' => {}
    }
  }

  def self.included_in_plan?(plan_name, boolean_attr, additionals = {})
    additionals ||= {}
    bools = Subscriptions.fetch(plan_name, {}).fetch('booleans', {})
    bools.merge!(additionals.fetch(plan_name, {}).fetch('booleans', {}))
    bools.fetch(boolean_attr, false) rescue false
  end
  def self.limit(plan_name, limit_attr, additionals = {})
    additionals ||= {}
    limits = Subscriptions.fetch(plan_name, {}).fetch('limits', {})
    limits.merge!(additionals.fetch(plan_name, {}).fetch('limits', {}))
    limits.fetch(limit_attr, nil) rescue nil
  end

  def self.sweetist
    Subscriptions.fetch('sweetist')
  end
  def self.sweetist_booleans
    Subscriptions.fetch('sweetist').fetch('booleans')
  end
  def self.sweetist_limits
    Subscriptions.fetch('sweetist').fetch('limits')
  end

  def self.starter
    Subscriptions.fetch('starter')
  end
  def self.starter_booleans
    Subscriptions.fetch('starter').fetch('booleans')
  end
  def self.starter_limits
    Subscriptions.fetch('starter').fetch('limits')
  end

  def self.plus
    Subscriptions.fetch('plus')
  end
  def self.plus_booleans
    Subscriptions.fetch('plus').fetch('booleans')
  end
  def self.plus_limits
    Subscriptions.fetch('plus').fetch('limits')
  end

  def self.platinum
    Subscriptions.fetch('platinum')
  end
  def self.platinum_booleans
    Subscriptions.fetch('platinum').fetch('booleans')
  end
  def self.platinum_limits
    Subscriptions.fetch('platinum').fetch('limits')
  end

  def self.enterprise
    Subscriptions.fetch('enterprise')
  end
  def self.enterprise_booleans
    Subscriptions.fetch('enterprise').fetch('booleans')
  end
  def self.enterprise_limits
    Subscriptions.fetch('enterprise').fetch('limits')
  end
end
