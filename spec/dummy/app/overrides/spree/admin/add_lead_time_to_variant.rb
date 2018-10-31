Deface::Override.new(:virtual_path => 'spree/admin/variants/_form',
  :name => 'add_lead_time_to_variant_edit',
  :insert_after => "[data-hook='tax_category']",
  :text => "<div class='form-group' data-hook='lead_time'>
	<%= f.label 'Lead Time (in days)' %>
	<%= f.number_field :lead_time, class: 'form-control' %>
</div>
          ")

Deface::Override.new(:virtual_path => 'spree/admin/products/_form',
  :name => 'add_lead_time_to_admin_product_form',
  :insert_after => "[data-hook='admin_product_form_sku']",
  :text => "<% if !@product.has_variants? %>
	<div class='alpha two columns' data-hook='admin_product_form_lead_time'>
		<%= f.field_container :lead_time, class: ['form-group'] do %>
			<%= f.label :lead_time, 'Lead Time (in days)' %>
			<%= f.number_field :lead_time, class: 'form-control' %>
			<%= f.error_message_on :lead_time %>
		<% end %>
	</div>
<% end %>
          ")
