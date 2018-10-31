Deface::Override.new(:virtual_path => 'spree/admin/orders/index',
  :name => 'override_order_filter',
  :replace => "[data-hook='admin_orders_index_search']",
  :partial => "spree/admin/orders/order_filters"
)
