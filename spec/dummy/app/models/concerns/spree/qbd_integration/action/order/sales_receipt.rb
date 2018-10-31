module Spree::QbdIntegration::Action::Order::SalesReceipt

  def qbd_order_to_sales_receipt_xml(xml, order_hash, match = nil)
    if match
      self.qbd_update_order_to_sales_receipt_xml(xml, order_hash, match)
    else
      self.qbd_new_order_to_sales_receipt_xml(xml, order_hash, nil)
    end
  end

  def qbd_new_order_to_sales_receipt_xml(xml, order_hash, match = nil)
    account = Spree::Account.find(order_hash.fetch(:account_id))
    account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    xml.CustomerRef do
      xml.ListID       account_match.try(:sync_id)
    end
    if self.vendor.track_order_class?
      if order_hash.fetch(:txn_class_id, nil).present?
        txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: order_hash.fetch(:txn_class_id, nil), integration_syncable_type: 'Spree::TransactionClass')
        xml.ClassRef do
          if txn_class_match.try(:sync_id)
            xml.ListID    txn_class_match.try(:sync_id)
          else
            xml.FullName  self.company.txn_classes.find_by_id(order_hash.fetch(:txn_class_id)).try(:fully_qualified_name)
          end
        end
      end
    end
    if self.integration_item.qbd_sales_receipt_template.present?
      xml.TemplateRef do
        xml.FullName       self.integration_item.qbd_sales_receipt_template
      end
    end
    xml.TxnDate        order_hash.fetch(:invoice_date).to_date.to_s
    xml.RefNumber      order_hash.fetch(:number)
    xml.BillAddress do
      qbd_address_to_address_xml(xml, order_hash.fetch(:bill_address, nil))
    end
    xml.ShipAddress do
      qbd_address_to_address_xml(xml, order_hash.fetch(:ship_address, nil))
    end
    xml.DueDate      order_hash.fetch(:due_date).to_date.to_s
    if account_hash.fetch(:account, {}).fetch(:rep_id)
      rep_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:rep_id), integration_syncable_type: 'Spree::Rep', sync_type: 'SalesRep')
      xml.SalesRepRef do
        xml.ListID    rep_match.try(:sync_id)
      end
    end
    unless self.vendor.try(:order_date_text).to_s.downcase == 'none'
      xml.ShipDate    order_hash.fetch(:delivery_date).to_date.to_s
    end
    if order_hash.fetch(:shipping_method_id)
      shipping_method_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_hash.fetch(:shipping_method_id), integration_syncable_type: 'Spree::ShippingMethod')
      xml.ShipMethodRef do
        if shipping_method_match.try(:sync_id)
          xml.ListID    shipping_method_match.try(:sync_id)
        else
          xml.FullName  order_hash.fetch(:shipping_method, {}).fetch(:name, '')
        end
      end
    end
    if self.integration_item.qbd_send_special_instructions_as == 'memo'
      xml.Memo           order_hash.fetch(:special_instructions)
    end
    if self.integration_item.qbd_is_to_be_printed
      xml.IsToBePrinted   true
    end
    if self.integration_item.qbd_deposit_to_account.present?
      xml.DepositToAccountRef do
        xml.FullName    self.integration_item.qbd_deposit_to_account
      end
    end
    order_hash.fetch(:line_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      if BUNDLE_TYPES.has_key?(line_item.fetch(:item_type))
        xml.SalesReceiptLineGroupAdd do
          xml.ItemRef do
            xml.ListID  variant_match.try(:sync_id)
          end
          xml.Quantity  line_item.fetch(:quantity)
          if self.integration_item.qbd_use_multi_site_inventory
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
            xml.InventorySiteRef do
              xml.ListID  stock_location_match.try(:sync_id)
            end
          end
        end
        parts_amount = line_item.fetch(:parts_variants).map{|pv| pv.fetch(:amount) }.inject(:+) || 0
        bundle_adjustment = line_item.fetch(:amount) - parts_amount
        unless bundle_adjustment.between?(-0.000001, 0.000001)
          xml.SalesReceiptLineAdd do
            xml.ItemRef do
              xml.FullName  self.integration_item.qbd_bundle_adjustment_name.to_s
            end
            xml.Desc      "Pricing adjustment for #{line_item.fetch(:item_name)}"
            # xml.Quantity  1
            xml.Rate      bundle_adjustment
            if self.integration_item.try(:qbd_collect_taxes)
              category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
              xml.SalesTaxCodeRef do
                xml.ListID  category_match.try(:sync_id)
              end
            end
            # xml.IsTaxable line_item.fetch(:adjustments, {}).fetch(:is_tax_present)
          end
        end
      else
        xml.SalesReceiptLineAdd do
          xml.ItemRef do
            xml.ListID  variant_match.try(:sync_id)
          end
          xml.Desc      qbd_sales_line_description(line_item)
          xml.Quantity  line_item.fetch(:quantity)
          xml.Rate      line_item.fetch(:discount_price)
          if self.vendor.track_line_item_class?
            if line_item.fetch(:txn_class_id, nil).present?
              txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: line_item.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
              xml.ClassRef do
                if txn_class_match.try(:sync_id)
                  xml.ListID    txn_class_match.try(:sync_id)
                else
                  xml.FullName  self.company.txn_classes.find_by_id(line_item.fetch(:txn_class_id)).try(:fully_qualified_name)
                end
              end
            end
          elsif self.integration_item.qbd_use_order_class_on_lines
            if order_hash.fetch(:txn_class_id, nil).present?
              txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: order_hash.fetch(:txn_class_id, nil), integration_syncable_type: 'Spree::TransactionClass')
              xml.ClassRef do
                if txn_class_match.try(:sync_id)
                  xml.ListID    txn_class_match.try(:sync_id)
                else
                  xml.FullName  self.company.txn_classes.find_by_id(order_hash.fetch(:txn_class_id)).try(:fully_qualified_name)
                end
              end
            end
          end
          if self.integration_item.qbd_use_multi_site_inventory
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
            xml.InventorySiteRef do
              xml.ListID  stock_location_match.try(:sync_id)
            end
          end
          if self.integration_item.qbd_track_lots
            xml.LotNumber   line_item.fetch(:lot_number)
          end
          if self.integration_item.try(:qbd_collect_taxes)
            category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
            xml.SalesTaxCodeRef do
              xml.ListID  category_match.try(:sync_id)
            end
          end
          # xml.IsTaxable line_item.fetch(:adjustments, {}).fetch(:is_tax_present)
        end
      end
    end

    if self.integration_item.qbd_group_discounts
      # unlike qbo, qbd expects (-) for discount
      discount_sum = order_hash.fetch(:adjustments, {}).fetch(:sum)
      unless discount_sum.between?(-0.000001, 0.000001)
        xml.SalesReceiptLineAdd do
          xml.ItemRef do
            xml.FullName     self.integration_item.qbd_discount_item_name
          end
          xml.Desc      self.integration_item.qbd_discount_item_name
          # xml.Quantity  1
          xml.Rate      discount_sum
        end
      end
    else
      order_hash.fetch(:adjustments, {}).fetch(:line_items, []).each do |line_item|
        xml.SalesReceiptLineAdd do
          xml.ItemRef do
            xml.FullName     line_item.fetch(:name)
          end
          xml.Desc      line_item.fetch(:name)
          xml.Quantity  1
          xml.Rate      line_item.fetch(:amount)
        end
      end
    end

    ship_total = order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
    if ship_total && ship_total > 0
      shipping_method = order_hash.fetch(:shipping_method, {})
      xml.SalesReceiptLineAdd do
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_shipping_item_name
        end
        xml.Desc      shipping_method.fetch(:name)
        xml.Quantity  1
        xml.Rate      shipping_method.fetch(:shipment_total)
      end
    end

    if self.integration_item.qbd_send_special_instructions_as == 'line_item'
      xml.SalesReceiptLineMod do
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_special_instructions_item
        end
        xml.Desc    order_hash.fetch(:special_instructions)
      end
    end

    # Return XML
    xml
  end

  def qbd_update_order_to_sales_receipt_xml(xml, order_hash, match = nil)
    xml.TxnID          match.try(:sync_id)
    xml.EditSequence   match.try(:sync_alt_id)

    account = Spree::Account.find(order_hash.fetch(:account_id))
    account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    xml.CustomerRef do
      xml.ListID       account_match.try(:sync_id)
    end
    if self.vendor.track_order_class?
      if order_hash.fetch(:txn_class_id, nil).present?
        txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: order_hash.fetch(:txn_class_id, nil), integration_syncable_type: 'Spree::TransactionClass')
        xml.ClassRef do
          if txn_class_match.try(:sync_id)
            xml.ListID    txn_class_match.try(:sync_id)
          else
            xml.FullName  self.company.txn_classes.find_by_id(order_hash.fetch(:txn_class_id)).try(:fully_qualified_name)
          end
        end
      end
    end
    if self.integration_item.qbd_sales_receipt_template.present?
      xml.TemplateRef do
        xml.FullName       self.integration_item.qbd_sales_receipt_template
      end
    end
    xml.TxnDate        order_hash.fetch(:invoice_date).to_date.to_s
    xml.RefNumber      order_hash.fetch(:number)
    xml.BillAddress do
      qbd_address_to_address_xml(xml, order_hash.fetch(:bill_address, nil))
    end
    xml.ShipAddress do
      qbd_address_to_address_xml(xml, order_hash.fetch(:ship_address, nil))
    end
    xml.DueDate      order_hash.fetch(:due_date).to_date.to_s
    if account_hash.fetch(:account, {}).fetch(:rep_id)
      rep_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:rep_id), integration_syncable_type: 'Spree::Rep', sync_type: 'SalesRep')
      xml.SalesRepRef do
        xml.ListID    rep_match.try(:sync_id)
      end
    end
    unless self.vendor.try(:order_date_text).to_s.downcase == 'none'
      xml.ShipDate    order_hash.fetch(:delivery_date).to_date.to_s
    end
    if order_hash.fetch(:shipping_method_id)
      shipping_method_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_hash.fetch(:shipping_method_id), integration_syncable_type: 'Spree::ShippingMethod')
      xml.ShipMethodRef do
        if shipping_method_match.try(:sync_id)
          xml.ListID    shipping_method_match.try(:sync_id)
        else
          xml.FullName  order_hash.fetch(:shipping_method, {}).fetch(:name, '')
        end
      end
    end
    if self.integration_item.qbd_send_special_instructions_as == 'memo'
      xml.Memo           order_hash.fetch(:special_instructions)
    end
    if self.integration_item.qbd_is_to_be_printed
      xml.IsToBePrinted   true
    end
    if self.integration_item.qbd_deposit_to_account.present?
      xml.DepositToAccountRef do
        xml.FullName    self.integration_item.qbd_deposit_to_account
      end
    end
    order_hash.fetch(:line_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      line_item_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:self).try(:id), integration_syncable_type: 'Spree::LineItem')
      if BUNDLE_TYPES.has_key?(line_item.fetch(:item_type))
        xml.SalesReceiptLineGroupMod do
          xml.TxnLineID line_item_match.sync_id.blank? ? -1 : line_item_match.sync_id    # -1 is for new line items
          xml.ItemGroupRef do
            xml.ListID  variant_match.try(:sync_id)
          end
          xml.Quantity  line_item.fetch(:quantity)

          line_item.fetch(:parts_variants, []).each do |part_variant|
            part_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: part_variant.fetch(:part_id), integration_syncable_type: 'Spree::Variant')
            part_line_match = nil
            qbd_sales_receipt_line_mod(xml, order_hash, part_variant, part_match)
          end

          # add ajustment line if bundle total is not equal to sum of parts
          parts_amount = line_item.fetch(:parts_variants).map{|pv| pv.fetch(:amount) }.inject(:+) || 0
          bundle_adjustment = line_item.fetch(:amount) - parts_amount
          unless bundle_adjustment.between?(-0.000001, 0.000001)
            xml.SalesReceiptLineMod do
              xml.TxnLineID -1
              xml.ItemRef do
                xml.FullName  self.integration_item.qbd_bundle_adjustment_name.to_s
              end
              xml.Desc      "Pricing adjustment for #{line_item.fetch(:item_name)}"
              # xml.Quantity  1
              xml.Rate      bundle_adjustment

              if self.integration_item.try(:qbd_collect_taxes)
                category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
                xml.SalesTaxCodeRef do
                  xml.ListID  category_match.try(:sync_id)
                end
              end
              # xml.IsTaxable line_item.fetch(:adjustments, {}).fetch(:is_tax_present)
            end
          end
        end
      else
        qbd_sales_receipt_line_mod(xml, order_hash, line_item, variant_match, line_item_match)
      end
    end

    if self.integration_item.qbd_group_discounts
      # unlike qbo, qbd expects (-) for discount
      discount_sum = order_hash.fetch(:adjustments, {}).fetch(:sum)
      unless discount_sum.between?(-0.000001, 0.000001)
        xml.SalesReceiptLineMod do
          xml.TxnLineID -1
          xml.ItemRef do
            xml.FullName     self.integration_item.qbd_discount_item_name
          end
          xml.Desc      self.integration_item.qbd_discount_item_name
          # xml.Quantity  1
          xml.Rate      discount_sum
        end
      end
    else
      order_hash.fetch(:adjustments, {}).fetch(:line_items, []).each do |line_item|
        xml.SalesReceiptLineMod do
          xml.TxnLineID -1
          xml.ItemRef do
            xml.FullName     line_item.fetch(:name)
          end
          xml.Desc      line_item.fetch(:name)
          xml.Quantity  1
          xml.Rate      line_item.fetch(:amount)
        end
      end
    end

    ship_total = order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
    if ship_total && ship_total > 0
      shipping_method = order_hash.fetch(:shipping_method, {})
      xml.SalesReceiptLineMod do
        xml.TxnLineID -1
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_shipping_item_name
        end
        xml.Desc      shipping_method.fetch(:name)
        xml.Quantity  1
        xml.Rate      shipping_method.fetch(:shipment_total)
      end
    end

    if self.integration_item.qbd_send_special_instructions_as == 'line_item'
      xml.SalesReceiptLineMod do
        xml.TxnLineID -1
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_special_instructions_item
        end
        xml.Desc    order_hash.fetch(:special_instructions)
      end
    end

    # Return XML
    xml
  end

  def qbd_sales_receipt_line_mod(xml, order_hash, line_item, variant_match, line_item_match = nil)
    xml.SalesReceiptLineMod do
      if line_item_match.try(:sync_id).blank? || self.integration_item.qbd_force_line_position
        xml.TxnLineID -1 # -1 is for new line items
      else
        xml.TxnLineID line_item_match.sync_id
      end
      xml.ItemRef do
        xml.ListID  variant_match.try(:sync_id)
      end
      xml.Desc      qbd_sales_line_description(line_item)
      xml.Quantity  line_item.fetch(:quantity)
      xml.Rate      line_item.fetch(:discount_price)
      if self.vendor.track_line_item_class?
        if line_item.fetch(:txn_class_id, nil).present?
          txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: line_item.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
          xml.ClassRef do
            if txn_class_match.try(:sync_id)
              xml.ListID    txn_class_match.try(:sync_id)
            else
              xml.FullName  self.company.txn_classes.find_by_id(line_item.fetch(:txn_class_id)).try(:fully_qualified_name)
            end
          end
        end
      elsif self.integration_item.qbd_use_order_class_on_lines
        if order_hash.fetch(:txn_class_id, nil).present?
          txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: order_hash.fetch(:txn_class_id, nil), integration_syncable_type: 'Spree::TransactionClass')
          xml.ClassRef do
            if txn_class_match.try(:sync_id)
              xml.ListID    txn_class_match.try(:sync_id)
            else
              xml.FullName  self.company.txn_classes.find_by_id(order_hash.fetch(:txn_class_id)).try(:fully_qualified_name)
            end
          end
        end
      end
      if self.integration_item.qbd_use_multi_site_inventory
        stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
        xml.InventorySiteRef do
          xml.ListID  stock_location_match.try(:sync_id)
        end
      end
      if self.integration_item.qbd_track_lots
        xml.LotNumber   line_item.fetch(:lot_number)
      end
      if self.integration_item.try(:qbd_collect_taxes)
        category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
        xml.SalesTaxCodeRef do
          xml.ListID  category_match.try(:sync_id)
        end
      end
      # xml.IsTaxable line_item.fetch(:adjustments, {}).fetch(:is_tax_present)
    end
  end

  def qbd_order_to_void_sales_receipt_xml(xml, order_hash, match = nil)
    xml.TxnVoidType   'SalesReceipt'
    xml.TxnID         match.try(:sync_id)
  end

  def qbd_sales_receipt_xml_to_order(response, order_hash)
    {}
  end

end
