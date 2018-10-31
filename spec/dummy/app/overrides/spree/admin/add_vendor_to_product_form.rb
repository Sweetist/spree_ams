Deface::Override.new(:virtual_path => 'spree/admin/products/new',
  :name => 'add_vendor_to_new_product',
  :insert_after => "[data-hook='new_product_shipping_category']",
  :text => "<div data-hook='new_product_vendor' class='col-md-4'>
            <%= f.field_container :vendor, :class => ['form-group'] do %>
            <%= f.label :vendor_id, Spree.t(:vendors) %><span class='required'>*</span>
            <%= f.collection_select(:vendor_id, Spree::Company.all, :id, :name, { :include_blank => Spree.t('match_choices') }, { :class => 'select2' }) %>
            <%= f.error_message_on :vendors %>
            <% end %>
            </div>"
  )

Deface::Override.new(:virtual_path => 'spree/admin/products/_form',
  :name => 'add_vendor_to_product_form',
  :insert_after => "[data-hook='admin_product_form_slug']",
  :text => "<div data-hook='new_product_vendor'>
            <%= f.field_container :vendor, :class => ['form-group'] do %>
            <%= f.label :vendor_id, Spree.t(:vendors) %><span class='required'>*</span>
            <%= f.collection_select(:vendor_id, Spree::Company.all, :id, :name, { :include_blank => Spree.t('match_choices') }, { :class => 'select2' }) %>
            <%= f.error_message_on :vendors %>
            <% end %>
            </div>"
  )
