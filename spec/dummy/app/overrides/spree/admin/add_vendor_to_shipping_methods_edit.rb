Deface::Override.new(
  virtual_path: 'spree/admin/shipping_categories/_form',
  name:'add_vendor_to_shipping_categories_form_fields',
  replace: "[data-hook='name']",
  text:
        "<div data-hook='name' class='form-group'>
          <%= f.field_container :name, class: ['form-group'] do %>
            <%= f.label :name, Spree.t(:name) %><br>
            <%= f.text_field :name, class: 'form-control' %>
            <%= f.error_message_on :name %>
          <% end %>
          <%= f.field_container :vendor, class: ['form-group'] do %>
            <%= f.label :vendor, Spree.t(:vendor) %>
            <%= f.collection_select(:vendor_id, Spree::Company.all, :id, :name, {include_blank: ''}, {class: 'select2'}) %>
          <% end %>
        </div>"
)
