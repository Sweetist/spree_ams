Deface::Override.new(:virtual_path => 'spree/layouts/spree_application',
  :name => 'remove_spree_header',
  :replace => "body",
  :text => "<body><%= yield %></body>"
)
