Deface::Override.new(:virtual_path => 'spree/admin/promotions/_form',
  :name => 'override_shipment_status',
  :insert_top => "div.col-md-6",
  :text => "<%= f.field_container :vendor_id, class: ['form-group'] do %>
      <%= f.label 'Vendor' %>
      <%= f.collection_select :vendor_id, Spree::Company.all.order('name ASC'), :id, :name, {include_blank: true}, class: 'form-control' %>
    <% end %>"
  )
