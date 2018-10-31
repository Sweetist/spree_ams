Deface::Override.new(
  virtual_path: 'spree/admin/tax_rates/_form',
  name:'add_vendor_to_tax_rate_form_fields',
  replace: "[data-hook='category']",
  text:
        "<div data-hook='category' class='form-group'>
          <%= f.label :tax_category_id, Spree.t(:tax_category) %>
          <%= f.collection_select(:tax_category_id, @available_categories, :id, :cat_and_vendor_name, {}, {:class => 'select2'}) %>
        </div>"
)
