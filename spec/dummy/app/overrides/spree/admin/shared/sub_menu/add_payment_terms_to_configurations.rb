Deface::Override.new(:virtual_path => 'spree/admin/shared/sub_menu/_configuration',
  :name => 'add_payment_terms_to_configurations',
  :insert_bottom => "[data-hook='admin_configurations_sidebar_menu']",
  :text => "<%= configurations_sidebar_menu_item(Spree.t(:payment_terms), spree.admin_payment_terms_path) %>"
)
