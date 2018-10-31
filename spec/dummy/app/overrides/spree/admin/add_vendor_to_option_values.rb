Deface::Override.new(:virtual_path => 'spree/admin/option_types/edit',
:name => 'add_vendor_table_header',
:replace => "[data-hook='option_header']",
:text => "
<thead data-hook='option_header'>
  <tr>
  <th colspan='2'>Vendor<span class='required'>*</span></th>
  <th><%= Spree.t(:name) %> <span class='required'>*</span></th>
  <th><%= Spree.t(:display) %> <span class='required'>*</span></th>
  <th class='actions'></th>
  </tr>
</thead>"
)
Deface::Override.new(:virtual_path => 'spree/admin/option_types/_option_value_fields',
  :name => 'add_vendor_to_option_value',
  :insert_before => "td.name",
  :text => "<td>
            <%= f.collection_select(:vendor_id, Spree::Company.all.order('name ASC'), :id, :name ) %>
            </td>"
  )
