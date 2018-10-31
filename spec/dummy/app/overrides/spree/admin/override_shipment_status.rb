Deface::Override.new(:virtual_path => 'spree/admin/shared/_order_summary',
  :name => 'override_shipment_status',
  :replace => "td#shipment_status",
  :text => "<td id='shipment_state'>
              <% shipment_label = @order.shipment_state %>
              <span class='state label label-<%= shipment_label %>'>
               <%= @order.shipment_state ? Spree.t(@order.shipment_state) : 'None'%>
              </span>
            </td>"
  )
