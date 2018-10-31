Deface::Override.new(
  virtual_path: 'spree/admin/tax_categories/index',
  name:'add_vendor_name_to_tax_categories_table_header',
  replace: "[data-hook='tax_header']",
  text:
        "<tr data-hook='tax_header'>
          <th><%= Spree.t(:name) %></th>
          <th><%= Spree.t(:vendor) %></th>
          <th><%= Spree.t(:tax_code) %></th>
          <th><%= Spree.t(:description) %></th>
          <th><%= Spree.t(:default) %></th>
          <th></th>
        </tr>"
)
Deface::Override.new(
  virtual_path: 'spree/admin/tax_categories/index',
  name: 'add_vendor_name_to_tax_categories_table',
  replace: "[data-hook='tax_row']",
  text:
        "<tr id=\"<%= spree_dom_id tax_category %>\" data-hook='tax_row'>
          <td><%= tax_category.name %></td>
          <td><%= tax_category.try(:vendor).try(:name) %></td>
          <td><%= tax_category.tax_code %></td>
          <td><%= tax_category.description %></td>
          <td><%= tax_category.is_default? ? Spree.t(:say_yes) : Spree.t(:say_no) %></td>
          <td class='actions actions-2 text-right'>
            <%= link_to_edit(tax_category, no_text: true) if can? :edit, tax_category %>
            <%= link_to_delete(tax_category, no_text: true) if can? :delete, tax_category %>
          </td>
        </tr>"
  )
