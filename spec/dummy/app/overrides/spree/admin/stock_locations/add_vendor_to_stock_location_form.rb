Deface::Override.new(
  virtual_path: 'spree/admin/stock_locations/_form',
  name:'add_vendor_to_stock_location_form',
  :insert_after => "[data-hook='stock_location_admin_name']",
  :text => "<%= f.field_container :vendor, class: ['form-group'] do %>
            <%= f.label :vendor, Spree.t(:vendor) %><span class='required'>*</span>
            <%= f.collection_select(:vendor_id, Spree::Company.all, :id, :name, {include_blank: true}, {class: 'select2'}) %>
            <% end %>"
  )
