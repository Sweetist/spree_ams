Deface::Override.new(
  virtual_path: 'spree/admin/shipping_categories/index',
  name:'add_vendor_name_to_shipping_categories_table_header',
  replace: "[data-hook='categories_header']",
  text:
        "<tr data-hook='categories_header'>
          <th><%= Spree.t(:name) %></th>
          <th><%= Spree.t(:vendor) %></th>
          <th class='actions'></th>
        </tr>"
)
Deface::Override.new(
  virtual_path: 'spree/admin/shipping_categories/index',
  name: 'add_vendor_name_to_shipping_categories_table',
  replace: "[data-hook='category_row']",
  text:
        "<tr id=\"<%= spree_dom_id shipping_category %>\" data-hook='category_row'>
          <td><%= shipping_category.name %></td>
          <td><%= shipping_category.try(:vendor).try(:name) %></td>
          <td class='actions actions-2 text-right'>
            <%= link_to_edit(shipping_category, no_text: true) if can? :edit, shipping_category %>
            <%= link_to_delete(shipping_category, no_text: true) if can? :edit, shipping_category %>
          </td>
        </tr>"
  )
