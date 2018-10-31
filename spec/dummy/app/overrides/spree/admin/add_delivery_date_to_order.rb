Deface::Override.new(:virtual_path => 'spree/admin/orders/edit',
  :name => 'add_delivery_date_to_order',
  :insert_after => "[data-hook='admin_order_edit_form']",
  :partial => "spree/admin/orders/delivery_date"
)
