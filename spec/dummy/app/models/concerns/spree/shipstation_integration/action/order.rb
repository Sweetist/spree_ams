module Spree::ShipstationIntegration::Action::Order
  # include Spree::ShipstationIntegration::Action::Order::Invoice
  # include Spree::ShipstationIntegration::Action::Order::SalesReceipt
  #
  # Order
  #
  def shipstation_order_step(order_id)
    order = Spree::Order.find(order_id)
    order_hash = order.to_integration(
        self.integration_item.integrationable_options_for(order)
      )
    # # Sync account
    # account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_hash.fetch(:account_id), integration_syncable_type: 'Spree::Account')
    # if account_match.synced_at.nil? || account_match.synced_at < Time.current - 2.minute
    #   return self.shipstation_account_step(account_match.integration_syncable_id)
    # end
    # Sync Variants
    # order_hash.fetch(:line_items, []).each do |line_item|
    #   variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
    #   if variant_match.synced_at.nil? || variant_match.synced_at < Time.current - 2.minute
    #     return self.shipstation_variant_step(variant_match.integration_syncable_id)
    #   end
    # end
    # # Sync Tax Categories
    # order_hash.fetch(:line_items, []).each do |line_item|
    #   if line_item.fetch(:tax_category_id)
    #     category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
    #     if category_match.synced_at.nil? || category_match.synced_at < Time.current - 2.minute
    #       return self.shipstation_tax_category_step(category_match.integration_syncable_id)
    #     end
    #   end
    # end

    # if self.integration_item.shipstation_use_multi_site_inventory
    #   # Sync Stock Locations
    #   order_hash.fetch(:shipments, []).each do |shipment|
    #     if shipment.fetch(:stock_location_id)
    #       stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: shipment.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
    #       if stock_location_match.synced_at.nil? || stock_location_match.synced_at < Time.current - 2.minute
    #         return self.shipstation_stock_location_step(stock_location_match.integration_syncable_id)
    #       end
    #     end
    #   end
    # end

    # Sync Order
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_id, integration_syncable_type: 'Spree::Order')
    # ssxml_class = self.integration_item.shipstation_send_as_invoice ? 'Invoice' : 'SalesReceipt'
    ssxml_class = 'Order'
    if match.sync_id.nil?
      { step_type: :query, object_id: order_id, object_class: 'Spree::Order', ssxml_class: ssxml_class, ssxml_query_by: 'TxnID', ssxml_match_by: 'TxnID' }
    elsif match.sync_id.empty?
      { step_type: :create, object_id: order_id, object_class: 'Spree::Order', ssxml_class: ssxml_class, ssxml_query_by: 'TxnID', ssxml_match_by: 'TxnID' }
    else
      { step_type: :push, object_id: order_id, object_class: 'Spree::Order', ssxml_class: ssxml_class, ssxml_query_by: 'TxnID', ssxml_match_by: 'TxnID' }
    end
  end



  # def shipstation_order_to_invoice_xml(xml, order_hash, match = nil, step)
  #   if match
  #     self.shipstation_update_order_to_invoice_xml(xml, order_hash, match, step)
  #   else
  #     self.shipstation_new_order_to_invoice_xml(xml, order_hash, nil, step)
  #   end
  # end
  #
  # def shipstation_new_order_to_invoice_xml(xml, order_hash, match = nil, step)
  #   account = Spree::Account.find(order_hash.fetch(:account_id))
  #   account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
  #   account_hash = account.to_integration
  #   xml.CustomerRef do
  #     xml.ListID       account_match.try(:sync_id)
  #   end
  #   xml.TxnDate        order_hash.fetch(:delivery_date).to_date.to_s
  #   xml.RefNumber      order_hash.fetch(:number)
  #   bill_address = account_hash.fetch(:bill_address, {})
  #   ship_address = account_hash.fetch(:ship_address, {})
  #   xml.BillAddress do
  #     xml.Addr1        bill_address.fetch(:address1, '')
  #     xml.Addr2        bill_address.fetch(:address2, '')
  #     xml.City         bill_address.fetch(:city, '')
  #     xml.State        Spree::State.where(id: bill_address.fetch(:state_id, nil)).first.try(:name).to_s
  #     xml.PostalCode   bill_address.fetch(:zipcode, '')
  #     xml.Country      Spree::Country.where(id: bill_address.fetch(:country_id, nil)).first.try(:name).to_s
  #   end
  #   xml.ShipAddress do
  #     xml.Addr1        ship_address.fetch(:address1, '')
  #     xml.Addr2        ship_address.fetch(:address2, '')
  #     xml.City         ship_address.fetch(:city, '')
  #     xml.State        Spree::State.where(id: ship_address.fetch(:state_id, nil)).first.try(:name).to_s
  #     xml.PostalCode   ship_address.fetch(:zipcode, '')
  #     xml.Country      Spree::Country.where(id: ship_address.fetch(:country_id, nil)).first.try(:name).to_s
  #   end
  #   xml.PONumber       order_hash.fetch(:po_number)
  #   xml.Memo           order_hash.fetch(:special_instructions)
  #   # xml.IsTaxIncluded  order_hash.fetch()
  #   order_hash.fetch(:line_items, []).each do |line_item|
  #     variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
  #     xml.InvoiceLineAdd do
  #       xml.ItemRef do
  #         xml.ListID  variant_match.try(:sync_id)
  #       end
  #       xml.Desc      line_item.fetch(:fully_qualified_description)
  #       xml.Quantity  line_item.fetch(:quantity)
  #       xml.Rate      line_item.fetch(:discount_price)
  #       if self.integration_item.shipstation_use_multi_site_inventory
  #         stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
  #         xml.InventorySiteRef do
  #           xml.ListID  stock_location_match.try(:sync_id)
  #         end
  #       end
  #       category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
  #       xml.SalesTaxCodeRef do
  #         xml.ListID  category_match.try(:sync_id)
  #       end
  #       # xml.IsTaxable line_item.fetch(:adjustments, {}).fetch(:is_tax_present)
  #     end
  #   end
  #
  #   order_hash.fetch(:adjustments, {}).fetch(:line_items, []).each do |line_item|
  #     xml.InvoiceLineAdd do
  #       xml.ItemRef do
  #         xml.FullName     line_item.fetch(:name)
  #       end
  #       xml.Desc      line_item.fetch(:name)
  #       xml.Quantity  1
  #       xml.Rate      line_item.fetch(:amount)
  #     end
  #   end
  #
  #   if order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
  #     shipping_method = order_hash.fetch(:shipping_method, {})
  #     xml.InvoiceLineAdd do
  #       xml.ItemRef do
  #         xml.FullName     shipping_method.fetch(:item_name)
  #       end
  #       xml.Desc      shipping_method.fetch(:name)
  #       xml.Quantity  1
  #       xml.Rate      shipping_method.fetch(:shipment_total)
  #     end
  #   end
  #   # Return XML
  #   xml
  # end
  #
  # def shipstation_update_order_to_invoice_xml(xml, order_hash, match = nil, step)
  #   xml.TxnID          match.try(:sync_id)
  #   xml.EditSequence   match.try(:sync_alt_id)
  #
  #   account = Spree::Account.find(order_hash.fetch(:account_id))
  #   account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
  #   account_hash = account.to_integration
  #   xml.CustomerRef do
  #     xml.ListID       account_match.try(:sync_id)
  #   end
  #   xml.TxnDate        order_hash.fetch(:delivery_date).to_date.to_s
  #   xml.RefNumber      order_hash.fetch(:number)
  #   bill_address = account_hash.fetch(:bill_address, {})
  #   ship_address = account_hash.fetch(:ship_address, {})
  #   xml.BillAddress do
  #     xml.Addr1        bill_address.fetch(:address1, '')
  #     xml.Addr2        bill_address.fetch(:address2, '')
  #     xml.City         bill_address.fetch(:city, '')
  #     xml.State        Spree::State.where(id: bill_address.fetch(:state_id, nil)).first.try(:name).to_s
  #     xml.PostalCode   bill_address.fetch(:zipcode, '')
  #     xml.Country      Spree::Country.where(id: bill_address.fetch(:country_id, nil)).first.try(:name).to_s
  #   end
  #   xml.ShipAddress do
  #     xml.Addr1        ship_address.fetch(:address1, '')
  #     xml.Addr2        ship_address.fetch(:address2, '')
  #     xml.City         ship_address.fetch(:city, '')
  #     xml.State        Spree::State.where(id: ship_address.fetch(:state_id, nil)).first.try(:name).to_s
  #     xml.PostalCode   ship_address.fetch(:zipcode, '')
  #     xml.Country      Spree::Country.where(id: ship_address.fetch(:country_id, nil)).first.try(:name).to_s
  #   end
  #   xml.PONumber       order_hash.fetch(:po_number)
  #   xml.Memo           order_hash.fetch(:special_instructions)
  #   # xml.IsTaxIncluded  order_hash.fetch()
  #   order_hash.fetch(:line_items, []).each do |line_item|
  #     variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
  #     line_item_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:self).try(:id), integration_syncable_type: 'Spree::LineItem')
  #     xml.InvoiceLineMod do
  #       xml.TxnLineID line_item_match.sync_id.blank? ? -1 : line_item_match.sync_id    # -1 is for new line items
  #       xml.ItemRef do
  #         xml.ListID  variant_match.try(:sync_id)
  #       end
  #       xml.Desc      line_item.fetch(:fully_qualified_description)
  #       xml.Quantity  line_item.fetch(:quantity)
  #       xml.Rate      line_item.fetch(:discount_price)
  #       if self.integration_item.shipstation_use_multi_site_inventory
  #         stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
  #         xml.InventorySiteRef do
  #           xml.ListID  stock_location_match.try(:sync_id)
  #         end
  #       end
  #       category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
  #       xml.SalesTaxCodeRef do
  #         xml.ListID  category_match.try(:sync_id)
  #       end
  #       # xml.IsTaxable line_item.fetch(:adjustments, {}).fetch(:is_tax_present)
  #     end
  #   end
  #
  #   order_hash.fetch(:adjustments, {}).fetch(:line_items, []).each do |line_item|
  #     xml.InvoiceLineMod do
  #       xml.TxnLineID -1
  #       xml.ItemRef do
  #         xml.FullName     line_item.fetch(:name)
  #       end
  #       xml.Desc      line_item.fetch(:name)
  #       xml.Quantity  1
  #       xml.Rate      line_item.fetch(:amount)
  #     end
  #   end
  #
  #   if order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
  #     shipping_method = order_hash.fetch(:shipping_method, {})
  #     xml.InvoiceLineMod do
  #       xml.TxnLineID -1
  #       xml.ItemRef do
  #         xml.FullName     shipping_method.fetch(:item_name)
  #       end
  #       xml.Desc      shipping_method.fetch(:name)
  #       xml.Quantity  1
  #       xml.Rate      shipping_method.fetch(:shipment_total)
  #     end
  #   end
  #
  #   # Return XML
  #   xml
  # end
  #
  # def shipstation_invoice_xml_to_order(response, order_hash, step)
  #   {}
  # end
end
