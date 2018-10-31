module Spree::QbdIntegration::Action::Order::Invoice

  def qbd_order_to_invoice_xml(xml, order_hash, match = nil)
    if match
      self.qbd_update_order_to_invoice_xml(xml, order_hash, match)
    else
      self.qbd_new_order_to_invoice_xml(xml, order_hash, nil)
    end
  end

  def qbd_new_order_to_invoice_xml(xml, order_hash, match = nil)
    account = Spree::Account.find(order_hash.fetch(:account_id))
    account_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    xml.CustomerRef do
      xml.ListID       account_match.try(:sync_id)
    end
    if self.vendor.track_order_class?
      if order_hash.fetch(:txn_class_id, nil).present?
        txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: order_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
        xml.ClassRef do
          if txn_class_match.try(:sync_id)
            xml.ListID    txn_class_match.try(:sync_id)
          else
            xml.FullName  self.company.txn_classes.find_by_id(order_hash.fetch(:txn_class_id)).try(:fully_qualified_name)
          end
        end
      end
    end
    if self.integration_item.qbd_accounts_receivable_account.present?
      xml.ARAccountRef do
        xml.FullName    self.integration_item.qbd_accounts_receivable_account
      end
    end
    if self.integration_item.qbd_invoice_template.present?
      xml.TemplateRef do
        xml.FullName       self.integration_item.qbd_invoice_template
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
    xml.PONumber       order_hash.fetch(:po_number)
    if account.payment_terms
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account,{}).fetch(:payment_term_id), integration_syncable_type: 'Spree::PaymentTerm')
      xml.TermsRef do
        if payment_term_match.try(:sync_id).present?
          xml.ListID     payment_term_match.sync_id
        else
          xml.FullName   account.payment_terms.name
        end
      end
      xml.DueDate      order_hash.fetch(:due_date).to_date.to_s
    end
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
    # xml.IsTaxIncluded  order_hash.fetch()
    order_hash.fetch(:line_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      if BUNDLE_TYPES.has_key?(line_item.fetch(:item_type))
        xml.InvoiceLineGroupAdd do
          xml.ItemGroupRef do
            xml.ListID  variant_match.try(:sync_id)
          end
          xml.Quantity  line_item.fetch(:quantity)
          if self.integration_item.qbd_use_multi_site_inventory && INVENTORY_TYPES.has_key?(line_item.fetch(:item_type))
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
            xml.InventorySiteRef do
              xml.ListID  stock_location_match.try(:sync_id)
            end
          end
        end
        parts_amount = line_item.fetch(:parts_variants).map{|pv| pv.fetch(:amount) }.inject(:+) || 0
        bundle_adjustment = line_item.fetch(:amount) - parts_amount
        unless bundle_adjustment.between?(-0.000001, 0.000001)
          xml.InvoiceLineAdd do
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
        xml.InvoiceLineAdd do
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
          if self.integration_item.qbd_use_multi_site_inventory && INVENTORY_TYPES.has_key?(line_item.fetch(:item_type))
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
            xml.InventorySiteRef do
              xml.ListID  stock_location_match.try(:sync_id)
            end
          end
          # if self.integration_item.qbd_track_lots
          #   xml.LotNumber   line_item.fetch(:lot_number)
          # end
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
        xml.InvoiceLineAdd do
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
        xml.InvoiceLineAdd do
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
      xml.InvoiceLineAdd do
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_shipping_item_name
        end
        # xml.Desc      shipping_method.fetch(:name)
        xml.Quantity  1
        xml.Rate      shipping_method.fetch(:shipment_total)
      end
    end

    if self.integration_item.qbd_send_special_instructions_as == 'line_item'
      xml.InvoiceLineAdd do
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_special_instructions_item
        end
        xml.Desc    order_hash.fetch(:special_instructions)
      end
    end
    # Return XML
    xml
  end

  def qbd_update_order_to_invoice_xml(xml, order_hash, match = nil)
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
        txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: order_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
        xml.ClassRef do
          if txn_class_match.try(:sync_id)
            xml.ListID    txn_class_match.try(:sync_id)
          else
            xml.FullName  self.company.txn_classes.find_by_id(order_hash.fetch(:txn_class_id)).try(:fully_qualified_name)
          end
        end
      end
    end
    if self.integration_item.qbd_accounts_receivable_account.present?
      xml.ARAccountRef do
        xml.FullName    self.integration_item.qbd_accounts_receivable_account
      end
    end
    if self.integration_item.qbd_invoice_template.present?
      xml.TemplateRef do
        xml.FullName       self.integration_item.qbd_invoice_template
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
    xml.PONumber       order_hash.fetch(:po_number)
    if account.payment_terms
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account,{}).fetch(:payment_term_id), integration_syncable_type: 'Spree::PaymentTerm')
      xml.TermsRef do
        if payment_term_match.try(:sync_id).present?
          xml.ListID     payment_term_match.sync_id
        else
          xml.FullName   account.payment_terms.name
        end
      end
      xml.DueDate      order_hash.fetch(:due_date).to_date.to_s
    end
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
    # xml.IsTaxIncluded  order_hash.fetch()
    order_hash.fetch(:line_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      line_item_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:self).try(:id), integration_syncable_type: 'Spree::LineItem')
      if BUNDLE_TYPES.has_key?(line_item.fetch(:item_type))
        xml.InvoiceLineGroupMod do
          xml.TxnLineID line_item_match.sync_id.blank? ? -1 : line_item_match.sync_id    # -1 is for new line items
          xml.ItemGroupRef do
            xml.ListID  variant_match.try(:sync_id)
          end

          xml.Quantity  line_item.fetch(:quantity)

          line_item.fetch(:parts_variants, []).each do |part_variant|
            part_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: part_variant.fetch(:part_id), integration_syncable_type: 'Spree::Variant')
            part_line_match = nil
            qbd_invoice_line_mod(xml, order_hash, part_variant, part_match)
          end

          # add ajustment line if bundle total is not equal to sum of parts
          parts_amount = line_item.fetch(:parts_variants).map{|pv| pv.fetch(:amount) }.inject(:+) || 0
          bundle_adjustment = line_item.fetch(:amount) - parts_amount
          unless bundle_adjustment.between?(-0.000001, 0.000001)
            xml.InvoiceLineMod do
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
        qbd_invoice_line_mod(xml, order_hash, line_item, variant_match, line_item_match)
      end
    end

    if self.integration_item.qbd_group_discounts
      # unlike qbo, qbd expects (-) for discount
      discount_sum = order_hash.fetch(:adjustments, {}).fetch(:sum)
      unless discount_sum.between?(-0.000001, 0.000001)
        xml.InvoiceLineMod do
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
        xml.InvoiceLineMod do
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
      xml.InvoiceLineMod do
        xml.TxnLineID -1
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_shipping_item_name
        end
        # xml.Desc      shipping_method.fetch(:name)
        xml.Quantity  1
        xml.Rate      shipping_method.fetch(:shipment_total)
      end
    end

    if self.integration_item.qbd_send_special_instructions_as == 'line_item'
      xml.InvoiceLineMod do
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

  def qbd_invoice_line_mod(xml, order_hash, line_item, variant_match, line_item_match = nil)
    xml.InvoiceLineMod do
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
      if self.integration_item.qbd_use_multi_site_inventory && INVENTORY_TYPES.has_key?(line_item.fetch(:item_type))
        stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
        xml.InventorySiteRef do
          xml.ListID  stock_location_match.try(:sync_id)
        end
      end
      # if self.integration_item.qbd_track_lots
      #   xml.LotNumber   line_item.fetch(:lot_number)
      # end
      if self.integration_item.try(:qbd_collect_taxes)
        category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
        xml.SalesTaxCodeRef do
          xml.ListID  category_match.try(:sync_id)
        end
      end
      # xml.IsTaxable line_item.fetch(:adjustments, {}).fetch(:is_tax_present)
    end
  end

  def qbd_order_to_void_invoice_xml(xml, order_hash, match = nil)
    xml.TxnVoidType   'Invoice'
    xml.TxnID         match.try(:sync_id)
  end

  def qbd_invoice_xml_to_order(response, order_hash)
    order = self.company.sales_orders.find_by_id(order_hash.fetch(:id))
    xpath_base = '//QBXML/QBXMLMsgsRs/InvoiceQueryRs/InvoiceRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("InvoiceRet", {})
    qbd_invoice_hash_to_order(qbd_hash, order)
    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_invoice?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/InvoiceQueryRs/InvoiceRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("InvoiceRet", {})

    qbd_invoice_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_invoice_create_order_sub_steps(qbd_hash)
    qbd_invoice_find_or_assign_associated_opts(qbd_hash)
    if self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
      qbd_invoice_hash_to_order(qbd_hash)
    end
  end

  def qbd_invoice_hash_to_order(qbd_hash, order = nil)
    if order.nil?
      order = qbd_order_find_by_name(qbd_hash.fetch('RefNumber', nil))
      order ||= self.company.sales_orders.new(
        channel: 'qbd',
        number: Spree::Order.number_from_integration(qbd_hash.fetch('RefNumber', nil), self.company.id),
        currency: self.company.try(:currency)
      )
    end
    #Set Date Fields
    invoice_date = qbd_hash.fetch('TxnDate', Time.current).to_date
    order.invoice_date = invoice_date
    order.delivery_date = qbd_hash.fetch('ShipDate', invoice_date).to_date
    order.due_date = qbd_hash.fetch('DueDate', invoice_date).to_date

    order.po_number = qbd_hash.fetch('PONumber', '')

    if self.integration_item.qbd_send_special_instructions_as == 'memo'
      order.special_instructions = qbd_hash.fetch('Memo', '')
    end

    #Set customer, line_items, shipping_method
    transaction do
      qbd_invoice_find_or_assign_associated_opts(qbd_hash, order)
      adjustment_total = order.adjustment_total
      order.adjustment_total = 0
      order.save!
      unless adjustment_total.zero?
        adjustment_name = self.integration_item.qbd_discount_item_name
        order.adjustments.create!(
          order: order,
          amount: adjustment_total,
          label: adjustment_name.present? ? adjustment_name : 'Discount'
        )
      end
      order.create_shipment! unless order.shipments.present?
      order.create_tax_charge!
      order.item_count = order.quantity
      order.updater.update

      order.persist_totals

      unless order.invoice.present?
        invoice = self.company.sales_invoices.create!(
          multi_order: false,
          number: order.display_number,
          account_id: order.account_id,
          invoice_date: order.invoice_date,
          due_date: order.due_date,
          start_date: order.invoice_date,
          end_date: order.invoice_date
        )
        order.invoice = invoice
        order.save!
      end

      if order.approved?
        order.update_invoice
      else
        order.approve
        while States[order.state] < States[self.integration_item.qbd_initial_order_state] && order.next; end
      end
    end

    qbd_create_or_update_match(order,
                              'Spree::Order',
                              qbd_hash.fetch('TxnID'),
                              'Invoice',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
  end

  def qbd_invoice_find_or_assign_associated_opts(qbd_hash, order = nil)
    account = qbd_find_account_by_id_or_name(qbd_hash, 'CustomerRef')
    order_txn_class = qbd_find_transaction_class_by_id_or_name(qbd_hash, 'ClassRef')
    shipping_method = qbd_find_shipping_method_by_id_or_name(qbd_hash, 'ShipMethodRef')
    tax_rate = qbd_find_tax_rate_by_id_or_name(qbd_hash, 'ItemSalesTaxRef')
    errors = []
    lines = []
    shipping_cost = 0
    adjustment_total = 0
    special_instructions = ''
    [qbd_hash.fetch('InvoiceLineRet', [])].flatten.each do |txn_line|
      begin
        item_name = txn_line.fetch('ItemRef', {}).fetch('FullName', nil)
        item_name ||= txn_line.fetch('ItemRef', {}).fetch('Name', nil)
        next if item_name.blank?
        next if self.integration_item.qbd_ignore_items.include?(item_name)
        tax_category = qbd_find_tax_category_by_id_or_name(txn_line, 'SalesTaxCodeRef')
        if txn_line.fetch('Amount', 0).to_d < 0
          adjustment_total += txn_line.fetch('Amount', 0).to_d
        elsif item_name == self.integration_item.qbd_shipping_item_name
          shipping_cost += txn_line.fetch('Amount', 0).to_d
        elsif self.integration_item.qbd_send_special_instructions_as == 'line_item' \
          && item_name == self.integration_item.qbd_special_instructions_item
          special_instructions = txn_line.fetch('Desc', '')
        else
          line_item = qbd_txn_line_to_line_item(txn_line, order)
          lines << line_item if line_item.present?
        end
      rescue Exception => e
        errors << e.message
      end
    end #end txn_line loop

    if self.integration_item.try(:qbd_ungroup_grouped_lines)
      [qbd_hash.fetch('InvoiceLineGroupRet', [])].flatten.each do |group_line|
        [group_line.fetch('InvoiceLineRet', [])].flatten.each do |txn_line|
          begin
            item_name = txn_line.fetch('ItemRef', {}).fetch('FullName', nil)
            item_name ||= txn_line.fetch('ItemRef', {}).fetch('Name', nil)
            next if item_name.blank?
            next if self.integration_item.qbd_ignore_items.include?(item_name)
            tax_category = qbd_find_tax_category_by_id_or_name(txn_line, 'SalesTaxCodeRef')
            if txn_line.fetch('Amount', 0).to_d < 0
              adjustment_total += txn_line.fetch('Amount', 0).to_d
            elsif item_name == self.integration_item.qbd_shipping_item_name
              shipping_cost += txn_line.fetch('Amount', 0).to_d
            else
              line_item = qbd_txn_line_to_line_item(txn_line, order)
              lines << line_item if line_item.present?
            end
          rescue Exception => e
            errors << e.message
          end
        end #end txn_line loop
      end
    else
      #TODO
      raise "Pulling grouped line items is not implemented yet."
    end

    if errors.present?
      raise errors.join("\n")
    end
    if order.present?
      order.adjustments.destroy_all
      unless adjustment_total.zero?
        order.adjustment_total = adjustment_total
      end
      order.account = account
      if account.nil?
        raise "Unable to find customer #{qbd_hash.fetch('CustomerRef', {}).fetch('FullName',nil)} for Invoice RefNumber: #{qbd_hash.fetch('RefNumber', nil)}"
      end

      if self.integration_item.qbd_send_special_instructions_as == 'line_item' #\
        order.special_instructions = special_instructions
      end
      order.ship_address_id = account.try(:default_ship_address).try(:id)
      order.bill_address_id = account.try(:bill_address).try(:id)
      order.email = order.set_email(account)
      order.txn_class_id = order_txn_class.try(:id)
      shipping_method ||= account.default_shipping_method
      shipping_method ||= self.integration_item.try(:default_shipping_method)
      order.shipping_method_id = shipping_method.try(:id)
      order.override_shipment_cost = true
      order.shipment_total = shipping_cost
    end
  end

  def qbd_invoice_query_xml(xml)
    xml.IncludeLineItems true
    xml.IncludeLinkedTxns true
  end

end
