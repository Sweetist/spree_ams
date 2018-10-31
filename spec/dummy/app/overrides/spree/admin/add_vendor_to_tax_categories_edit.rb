Deface::Override.new(
  virtual_path: 'spree/admin/tax_categories/_form',
  name:'add_vendor_to_tax_rate_form_fields',
  insert_before: "erb[loud]:contains('f.field_container :tax_code')",
  text:
        "<%= f.field_container :vendor, class: ['form-group'] do %>
          <%= f.label :vendor, Spree.t(:vendor) %>
          <%= f.collection_select(:vendor_id, Spree::Company.all, :id, :name, {include_blank: ''}, {class: 'select2'}) %>
        <% end %>"
)
