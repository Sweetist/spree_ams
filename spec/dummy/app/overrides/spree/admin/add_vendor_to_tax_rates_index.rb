Deface::Override.new(
  virtual_path: 'spree/admin/tax_rates/index',
  name:'add_vendor_name_to_tax_rates_table_header',
  replace: "[data-hook='rate_header']",
  text:
        "<tr data-hook='rate_header'>
          <th><%= Spree.t(:zone) %></th>
          <th><%= Spree.t(:name) %></th>
          <th><%= Spree.t(:vendor) %></th>
          <th><%= Spree.t(:tax_category) %></th>
          <th><%= Spree.t(:amount) %></th>
          <th><%= Spree.t(:included_in_price) %></th>
          <th><%= Spree.t(:show_rate_in_label) %></th>
          <th><%= Spree.t(:calculator) %></th>
          <th></th>
        </tr>"
)
Deface::Override.new(
  virtual_path: 'spree/admin/tax_rates/index',
  name: 'add_vendor_name_to_tax_rates_table',
  replace: "[data-hook='rate_row']",
  text:
        "<tr id=\"<%= spree_dom_id tax_rate %>\" data-hook='rate_row'>
          <td><%=tax_rate.zone.try(:name) || Spree.t(:not_available) %></td>
          <td><%=tax_rate.name %></td>
          <td><%= tax_rate.tax_category.try(:vendor).try(:name) %></td>
          <td><%=tax_rate.tax_category.try(:name) || Spree.t(:not_available) %></td>
          <td><%=tax_rate.amount %></td>
          <td><%=tax_rate.included_in_price? ? Spree.t(:say_yes) : Spree.t(:say_no) %></td>
          <td><%=tax_rate.show_rate_in_label? ? Spree.t(:say_yes) : Spree.t(:say_no) %></td>
          <td><%=tax_rate.calculator.to_s %></td>
          <td class='actions actions-2 text-right'>
            <%= link_to_edit(tax_rate, no_text: true) if can? :edit, tax_rate %>
            <%= link_to_delete(tax_rate, no_text: true) if can? :delete, tax_rate %>
          </td>
        </tr>"
  )
