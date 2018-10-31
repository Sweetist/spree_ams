Deface::Override.new(:virtual_path => 'spree/admin/variants/_form',
  :name => 'add_pack_size_to_variant_edit',
  :insert_after => "[data-hook='sku']",
  :text => "<div class='form-group' data-hook='pack_size'>
	<%= f.label :pack_size %>
  <span class='required'>*</span>
	<%= f.text_field :pack_size, class: 'form-control' %>
</div>
          ")

Deface::Override.new(:virtual_path => 'spree/admin/products/_form',
  :name => 'add_pack_size_to_admin_product_form',
  :insert_after => "[data-hook='admin_product_form_price']",
  :text => "<% if !@product.has_variants? %>
	<div class='alpha two columns' data-hook='admin_product_form_pack_size'>
		<%= f.field_container :pack_size, class: ['form-group field'] do %>
			<%= f.label :pack_size %>
      <span class='required'>*</span>
			<%= f.text_field :pack_size, class: 'form-control' %>
			<%= f.error_message_on :pack_size %>
		<% end %>
	</div>
<% end %>
          ")

Deface::Override.new(:virtual_path => 'spree/admin/products/new',
  :name => 'add_pack_size_to_new_product',
  :insert_after => "[data-hook='new_product_sku']",
  :text => "<div data-hook='new_pack_size' class='col-md-4'>
              <%= f.field_container :vendor, :class => ['form-group'] do %>
                <%= f.label :pack_size %>
                <span class='required'>*</span>
          			<%= f.text_field :pack_size, class: 'form-control' %>
          			<%= f.error_message_on :pack_size %>
          		<% end %>
            </div>"
  )
