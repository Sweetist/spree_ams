class Spree::Permission

  Permissions = {
    'none' => 0,
    'read' => 1,
    'write' => 2
  }

  def self.owner_permissions
    {
      "invoice" => 2,
      "order" => {
        "basic_options" => 2,
        "payments" => 2,
        "edit_line_item" => true,
        "approve_ship_receive" => true,
        "manual_adjustment" => true
      },
      "products" => {
        "catalog" => 2,
        "categories" => 2,
        "option_values" => 2
      },
      "purchase_orders" => {
        "basic_options" => 2,
        "vendors" => 2
      },
      "standing_orders" => {
        "basic_options" => 2,
        "standing_orders_schedule" => 2
      },
      "inventory" => {
        "basic_options" => 2,
        "stock_locations" => 2
      },
      "customers" => {
        "basic_options" => 2,
        "users" => 2
      },
      "users" => {
        "basic_options" => 2,
        "user_adjust" => true
      },
      "promotions" => 2,
      "reports" => {
        "basic_options" => 2,
        "production_reports" => 2
      },
      "settings" => {
        "integrations" => 2,
        "shipping_categories" => 2,
        "shipping_methods" => 2,
        "shipping_groups" => 2,
        "tax_categories" => 2,
        "payment_methods" => 2
      },
      'company' => 2
    }
  end

  def self.staff_permissions
    {
      "invoice" => 1,
      "order" => {
        "basic_options" => 1,
        "payments" => 1,
        "edit_line_item" => true,
        "approve_ship_receive" => true,
        "manual_adjustment" => false
      },
      "products" => {
        "catalog" => 1,
        "categories" => 1,
        "option_values" => 1
      },
      "purchase_orders" => {
        "basic_options" => 1,
        "vendors" => 1
      },
      "standing_orders" => {
        "basic_options" => 1,
        "standing_orders_schedule" => 1
      },
      "inventory" => {
        "basic_options" => 1,
        "stock_locations" => 1,
      },
      "customers" => {
        "basic_options" => 1,
        "users" => 1
      },
      "users" => {
        "basic_options" => 1,
        "user_adjust" => false
      },
      "promotions" => 1,
      "reports" => {
        "basic_options" => 1,
        "production_reports" => 1
      },
      "settings" => {
        "integrations" => 1,
        "shipping_categories" => 1,
        "shipping_methods" => 1,
        "shipping_groups" => 1,
        "tax_categories" => 1,
        "payment_methods" => 1
      },
      'company' => 1
    }
  end

  def self.operations_permissions
    {
      "invoice" => 0,
      "order" => {
        "basic_options" => 0,
        "payments" => 0,
        "edit_line_item" => false,
        "approve_ship_receive" => false,
        "manual_adjustment" => false
      },
      "products" => {
        "catalog" => 1,
        "categories" => 1,
        "option_values" => 1
      },
      "purchase_orders" => {
        "basic_options" => 2,
        "vendors" => 2
      },
      "standing_orders" => {
        "basic_options" => 0,
        "standing_orders_schedule" => 0
      },
      "inventory" => {
        "basic_options" => 2,
        "stock_locations" => 2,
      },
      "customers" => {
        "basic_options" => 1,
        "users" => 1
      },
      "users" => {
        "basic_options" => 1,
        "user_adjust" => false
      },
      "promotions" => 0,
      "reports" => {
        "basic_options" => 0,
        "production_reports" => 2
      },
      "settings" => {
        "integrations" => 1,
        "shipping_categories" => 0,
        "shipping_methods" => 1,
        "shipping_groups" => 0,
        "tax_categories" => 0,
        "payment_methods" => 0
      },
      'company' => 1
    }
  end


end
