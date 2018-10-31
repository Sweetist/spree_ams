module Spree::QbdIntegration::Action::CreditMemo
  #
  # CreditMemo
  #
  def qbd_credit_memo_step(credit_memo_id, parent_step_id = nil)
    credit_memo = Spree::CreditMemo.find(credit_memo_id)
    credit_memo_hash = credit_memo.to_integration(
        self.integration_item.integrationable_options_for(credit_memo)
      )

    credit_memo_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: credit_memo_id, integration_syncable_type: 'Spree::CreditMemo')

    # Sync CreditMemo
    credit_memo_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: credit_memo_id, integration_syncable_type: 'Spree::CreditMemo')
    qbxml_class = 'CreditMemo'
    if credit_memo_match.sync_id.nil?
      next_step = { step_type: :query, object_id: credit_memo_id, object_class: 'Spree::CreditMemo', qbxml_class: qbxml_class, qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID' }
    elsif credit_memo_match.sync_id.empty?
      if credit_memo_hash.fetch(:line_items,[]).any?{ |line_item| BUNDLE_TYPES.has_key?(line_item.fetch(:item_type)) }
        next_step = { step_type: :create, next_step: :continue, object_id: credit_memo_id, object_class: 'Spree::CreditMemo', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
      else
        next_step = { step_type: :create, next_step: :skip, object_id: credit_memo_id, object_class: 'Spree::CreditMemo', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
      end
    elsif self.integration_item.qbd_overwrite_credit_memos_in == 'none'
      next_step = { step_type: :terminate, next_step: :skip, object_id: credit_memo_id, object_class: 'Spree::CreditMemo', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
    elsif self.integration_item.qbd_overwrite_credit_memos_in == 'sweet'
      raise "Updating credit memos in Sweet is not currently supported"
      next_step = qbd_credit_memo_pull_step_hash
    else
      next_step = qbd_credit_memo_push_step_hash
    end

    credit_memo_step = qbd_create_step(next_step)

    unless credit_memo_match.sync_id.nil?
    # Sync account
      account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: credit_memo_hash.fetch(:account_id), integration_syncable_type: 'Spree::Account')
      if account_match.synced_at.nil? || account_match.synced_at < Time.current - 10.minute
        qbd_create_step(
          self.qbd_account_step(account_match.integration_syncable_id, credit_memo_step.id),
          credit_memo_step.try(:id)
        )
      end

      if credit_memo_hash.fetch(:txn_class_id)
        txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: credit_memo_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
        if txn_class_match.synced_at.nil? || txn_class_match.synced_at < Time.current - 10.minute
          qbd_create_step(
            self.qbd_transaction_class_step(txn_class_match.integration_syncable_id, credit_memo_step.id),
            credit_memo_step.try(:id)
          )
        end
      end
      # Sync Variants
      credit_memo_hash.fetch(:line_items, []).each do |line_item|
        variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
        if variant_match.synced_at.nil? || variant_match.synced_at < Time.current - 10.minute
          qbd_create_step(
            self.qbd_variant_step(variant_match.integration_syncable_id, credit_memo_step.id),
            credit_memo_step.try(:id)
          )
        end
      end
      # Sync Tax Categories
      if self.integration_item.try(:qbd_collect_taxes)
        credit_memo_hash.fetch(:line_items, [])
                  .map {|li| li.fetch(:tax_category_id, nil)}
                  .compact.uniq.each do |tax_category_id|
                    category_match = self.integration_item.integration_sync_matches.find_or_create_by(
                      integration_syncable_id: tax_category_id,
                      integration_syncable_type: 'Spree::TaxCategory'
                    )
                    if category_match.synced_at.nil? || category_match.synced_at < Time.current - 10.minute
                      qbd_create_step(
                        self.qbd_tax_category_step(category_match.integration_syncable_id, credit_memo_step.id),
                        credit_memo_step.id
                      )
                    end
                  end
      end

      # Sync Classes
      credit_memo_hash.fetch(:line_items, []).each do |line_item|
        if line_item.fetch(:txn_class_id)
          txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
          if txn_class_match.synced_at.nil? || txn_class_match.synced_at < Time.current - 10.minute
            qbd_create_step(
              self.qbd_transaction_class_step(txn_class_match.integration_syncable_id, credit_memo_step.id),
              credit_memo_step.try(:id)
            )
          end
        end
      end

      # Sync ShippingMethod
      if credit_memo_hash.fetch(:shipping_method_id)
        shipping_method_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: credit_memo_hash.fetch(:shipping_method_id), integration_syncable_type: 'Spree::ShippingMethod')
        if shipping_method_match.synced_at.nil? || shipping_method_match.synced_at < Time.current - 10.minute
          qbd_create_step(
            self.qbd_shipping_method_step(shipping_method_match.integration_syncable_id, credit_memo_step.id),
            credit_memo_step.try(:id)
          )
        end
      end

      if self.integration_item.qbd_use_multi_site_inventory
        # Sync Stock Locations
        credit_memo_hash.fetch(:shipments, []).each do |shipment|
          if shipment.fetch(:stock_location_id)
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: shipment.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
            if stock_location_match.synced_at.nil? || stock_location_match.synced_at < Time.current - 10.minute
              qbd_create_step(
                self.qbd_stock_location_step(stock_location_match.integration_syncable_id, credit_memo_step.id),
                credit_memo_step.try(:id)
              )
            end
          end
        end
      end
    end

    # TODO
    # Find or Create Grouped Discount Item
    # unless credit_memo_hash.fetch(:adjustments, {}).fetch(:sum) == 0
    #   return self.qbd_find_or_create_item_other_charge(:qbd_discount_item_name, 'ItemDiscount')
    # end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_credit_memo_find_by_name(ref_number, channel = nil)
    credit_memo = self.company.credit_memos.where(
      number: Spree::CreditMemo.number_from_integration(ref_number, self.company.id)
    ).last

    (channel.blank? || credit_memo.try(:channel) == channel) ? credit_memo : nil
  end

  def qbd_find_credit_memo_by_id_or_name(hash, base_key)
    qbd_credit_memo_id = hash.fetch(base_key, {}).fetch('TxnID', nil)
    qbd_credit_memo_number = hash.fetch(base_key, {}).fetch('RefNumber', nil)
    qbxml_class = 'CreditMemo'
    return nil unless qbd_credit_memo_id.present? || qbd_credit_memo_number.present?

    credit_memo_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::CreditMemo',
      sync_id: qbd_credit_memo_id
    ).first

    credit_memo = self.company.credit_memos.where(id: credit_memo_match.try(:integration_syncable_id)).first
    credit_memo ||= qbd_credit_memo_find_by_name(qbd_credit_memo_number)

    if credit_memo.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::CreditMemo',
        sync_type: qbxml_class,
        sync_id: qbd_credit_memo_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_credit_memo_pull_step_hash.merge(
        {'qbxml_query_by' => 'TxnID', 'sync_id' => qbd_credit_memo_id, 'sync_full_name' => qbd_credit_memo_number}
      )

      sync_step.save
    end

    credit_memo
  end

  def qbd_credit_memo_to_credit_memo_xml(xml, credit_memo_hash, match = nil)
    if match
      self.qbd_update_credit_memo_to_credit_memo_xml(xml, credit_memo_hash, match)
    else
      self.qbd_new_credit_memo_to_credit_memo_xml(xml, credit_memo_hash, nil)
    end
  end

  def qbd_new_credit_memo_to_credit_memo_xml(xml, credit_memo_hash, match = nil)
    account = Spree::Account.find(credit_memo_hash.fetch(:account_id))
    account_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    xml.CustomerRef do
      xml.ListID       account_match.try(:sync_id)
    end
    if self.vendor.track_order_class?
      txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: credit_memo_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
      if txn_class_match.try(:sync_id)
        xml.ClassRef do
          xml.ListID    txn_class_match.try(:sync_id)
        end
      end
    end
    if self.integration_item.qbd_accounts_receivable_account.present?
      xml.ARAccountRef do
        xml.FullName    self.integration_item.qbd_accounts_receivable_account
      end
    end
    if self.integration_item.try(:qbd_credit_memo_template).present?
      xml.TemplateRef do
        xml.FullName       self.integration_item.qbd_credit_memo_template
      end
    end
    xml.TxnDate        credit_memo_hash.fetch(:credit_memo_date).to_date.to_s
    xml.RefNumber      credit_memo_hash.fetch(:number)
    xml.BillAddress do
      qbd_address_to_address_xml(xml, credit_memo_hash.fetch(:bill_address, nil))
    end
    xml.ShipAddress do
      qbd_address_to_address_xml(xml, credit_memo_hash.fetch(:ship_address, nil))
    end
    # xml.PONumber       credit_memo_hash.fetch(:po_number, nil)
    if account.payment_terms
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account,{}).fetch(:payment_term_id), integration_syncable_type: 'Spree::PaymentTerm')
      xml.TermsRef do
        xml.ListID     payment_term_match.try(:sync_id)
      end
      # xml.DueDate      credit_memo_hash.fetch(:due_date).to_date.to_s
    end
    if account_hash.fetch(:account, {}).fetch(:rep_id)
      rep_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:rep_id), integration_syncable_type: 'Spree::Rep', sync_type: 'SalesRep')
      xml.SalesRepRef do
        xml.ListID    rep_match.try(:sync_id)
      end
    end
    # unless self.vendor.try(:credit_memo_date_text).to_s.downcase == 'none'
    #   xml.ShipDate    credit_memo_hash.fetch(:delivery_date).to_date.to_s
    # end
    if credit_memo_hash.fetch(:shipping_method_id, nil)
      shipping_method_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: credit_memo_hash.fetch(:shipping_method_id), integration_syncable_type: 'Spree::ShippingMethod')
      xml.ShipMethodRef do
        xml.ListID    shipping_method_match.try(:sync_id)
      end
    end
    xml.Memo           credit_memo_hash.fetch(:note, nil)
    if self.integration_item.qbd_is_to_be_printed
      xml.IsToBePrinted   true
    end
    # xml.IsTaxIncluded  credit_memo_hash.fetch()
    credit_memo_hash.fetch(:line_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      if BUNDLE_TYPES.has_key?(line_item.fetch(:item_type))
        xml.CreditMemoLineGroupAdd do
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
          xml.CreditMemoLineAdd do
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
        xml.CreditMemoLineAdd do
          xml.ItemRef do
            xml.ListID  variant_match.try(:sync_id)
          end

          xml.Desc      qbd_sales_line_description(line_item)
          xml.Quantity  line_item.fetch(:quantity)
          xml.Rate      line_item.fetch(:discount_price)
          if self.vendor.track_line_item_class?
            txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: line_item.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
            if txn_class_match.try(:sync_id)
              xml.ClassRef do
                xml.ListID    txn_class_match.try(:sync_id)
              end
            end
          elsif self.integration_item.qbd_use_credit_memo_class_on_lines
            txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: credit_memo_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
            if txn_class_match.try(:sync_id)
              xml.ClassRef do
                xml.ListID    txn_class_match.try(:sync_id)
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
      discount_sum = credit_memo_hash.fetch(:adjustments, {}).fetch(:sum)
      unless discount_sum.between?(-0.000001, 0.000001)
        xml.CreditMemoLineAdd do
          xml.ItemRef do
            xml.FullName     self.integration_item.qbd_discount_item_name
          end
          xml.Desc      self.integration_item.qbd_discount_item_name
          # xml.Quantity  1
          xml.Rate      discount_sum
        end
      end
    else
      credit_memo_hash.fetch(:adjustments, {}).fetch(:line_items, []).each do |line_item|
        xml.CreditMemoLineAdd do
          xml.ItemRef do
            xml.FullName     line_item.fetch(:name)
          end
          xml.Desc      line_item.fetch(:name)
          xml.Quantity  1
          xml.Rate      line_item.fetch(:amount)
        end
      end
    end

    ship_total = credit_memo_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
    if ship_total && ship_total > 0
      shipping_method = credit_memo_hash.fetch(:shipping_method, {})
      xml.CreditMemoLineAdd do
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_shipping_item_name
        end
        # xml.Desc      shipping_method.fetch(:name)
        xml.Quantity  1
        xml.Rate      shipping_method.fetch(:shipment_total)
      end
    end
    # Return XML
    xml
  end

  def qbd_update_credit_memo_to_credit_memo_xml(xml, credit_memo_hash, match = nil)
    xml.TxnID          match.try(:sync_id)
    xml.EditSequence   match.try(:sync_alt_id)

    account = Spree::Account.find(credit_memo_hash.fetch(:account_id))
    account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    xml.CustomerRef do
      xml.ListID       account_match.try(:sync_id)
    end
    if self.vendor.track_order_class?
      txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: credit_memo_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
      if txn_class_match.try(:sync_id)
        xml.ClassRef do
          xml.ListID    txn_class_match.try(:sync_id)
        end
      end
    end
    if self.integration_item.qbd_accounts_receivable_account.present?
      xml.ARAccountRef do
        xml.FullName    self.integration_item.qbd_accounts_receivable_account
      end
    end
    if self.integration_item.try(:qbd_credit_memo_template).present?
      xml.TemplateRef do
        xml.FullName       self.integration_item.qbd_credit_memo_template
      end
    end
    xml.TxnDate        credit_memo_hash.fetch(:credit_memo_date).to_date.to_s
    xml.RefNumber      credit_memo_hash.fetch(:number)
    xml.BillAddress do
      qbd_address_to_address_xml(xml, credit_memo_hash.fetch(:bill_address, nil))
    end
    xml.ShipAddress do
      qbd_address_to_address_xml(xml, credit_memo_hash.fetch(:ship_address, nil))
    end
    xml.PONumber       credit_memo_hash.fetch(:po_number)
    if account.payment_terms
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account,{}).fetch(:payment_term_id), integration_syncable_type: 'Spree::PaymentTerm')
      xml.TermsRef do
        xml.ListID     payment_term_match.try(:sync_id)
      end
      xml.DueDate      credit_memo_hash.fetch(:due_date).to_date.to_s
    end
    if account_hash.fetch(:account, {}).fetch(:rep_id)
      rep_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:rep_id), integration_syncable_type: 'Spree::Rep', sync_type: 'SalesRep')
      xml.SalesRepRef do
        xml.ListID    rep_match.try(:sync_id)
      end
    end
    unless self.vendor.try(:credit_memo_date_text).to_s.downcase == 'none'
      xml.ShipDate    credit_memo_hash.fetch(:delivery_date).to_date.to_s
    end
    if credit_memo_hash.fetch(:shipping_method_id)
      shipping_method_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: credit_memo_hash.fetch(:shipping_method_id), integration_syncable_type: 'Spree::ShippingMethod')
      xml.ShipMethodRef do
        xml.ListID    shipping_method_match.try(:sync_id)
      end
    end
    xml.Memo           credit_memo_hash.fetch(:special_instructions)
    if self.integration_item.qbd_is_to_be_printed
      xml.IsToBePrinted   true
    end
    # xml.IsTaxIncluded  credit_memo_hash.fetch()
    credit_memo_hash.fetch(:line_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      line_item_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:self).try(:id), integration_syncable_type: 'Spree::LineItem')
      if BUNDLE_TYPES.has_key?(line_item.fetch(:item_type))
        xml.CreditMemoLineGroupMod do
          xml.TxnLineID line_item_match.sync_id.blank? ? -1 : line_item_match.sync_id    # -1 is for new line items
          xml.ItemGroupRef do
            xml.ListID  variant_match.try(:sync_id)
          end

          xml.Quantity  line_item.fetch(:quantity)

          line_item.fetch(:parts_variants, []).each do |part_variant|
            part_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: part_variant.fetch(:part_id), integration_syncable_type: 'Spree::Variant')
            part_line_match = nil
            qbd_credit_memo_line_mod(xml, credit_memo_hash, part_variant, part_match)
          end

          # add ajustment line if bundle total is not equal to sum of parts
          parts_amount = line_item.fetch(:parts_variants).map{|pv| pv.fetch(:amount) }.inject(:+) || 0
          bundle_adjustment = line_item.fetch(:amount) - parts_amount
          unless bundle_adjustment.between?(-0.000001, 0.000001)
            xml.CreditMemoLineMod do
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
        qbd_credit_memo_line_mod(xml, credit_memo_hash, line_item, variant_match, line_item_match)
      end
    end

    if self.integration_item.qbd_group_discounts
      # unlike qbo, qbd expects (-) for discount
      discount_sum = credit_memo_hash.fetch(:adjustments, {}).fetch(:sum)
      unless discount_sum.between?(-0.000001, 0.000001)
        xml.CreditMemoLineMod do
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
      credit_memo_hash.fetch(:adjustments, {}).fetch(:line_items, []).each do |line_item|
        xml.CreditMemoLineMod do
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

    ship_total = credit_memo_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
    if ship_total && ship_total > 0
      shipping_method = credit_memo_hash.fetch(:shipping_method, {})
      xml.CreditMemoLineMod do
        xml.TxnLineID -1
        xml.ItemRef do
          xml.FullName     self.integration_item.qbd_shipping_item_name
        end
        # xml.Desc      shipping_method.fetch(:name)
        xml.Quantity  1
        xml.Rate      shipping_method.fetch(:shipment_total)
      end
    end

    # Return XML
    xml
  end

  def qbd_credit_memo_line_mod(xml, credit_memo_hash, line_item, variant_match, line_item_match = nil)
    xml.CreditMemoLineMod do
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
        txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: line_item.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
        if txn_class_match.try(:sync_id)
          xml.ClassRef do
            xml.ListID    txn_class_match.try(:sync_id)
          end
        end
      elsif self.integration_item.qbd_use_credit_memo_class_on_lines
        txn_class_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: credit_memo_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
        if txn_class_match.try(:sync_id)
          xml.ClassRef do
            xml.ListID    txn_class_match.try(:sync_id)
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

  def qbd_credit_memo_to_void_credit_memo_xml(xml, credit_memo_hash, match = nil)
    xml.TxnVoidType   'CreditMemo'
    xml.TxnID         match.try(:sync_id)
  end

  def qbd_credit_memo_xml_to_credit_memo(response, credit_memo_hash)
    credit_memo = self.company.credit_memos.find_by_id(credit_memo_hash.fetch(:id))
    xpath_base = '//QBXML/QBXMLMsgsRs/CreditMemoQueryRs/CreditMemoRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("CreditMemoRet", {})
    qbd_credit_memo_hash_to_credit_memo(qbd_hash, credit_memo)
    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_credit_memo?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/CreditMemoQueryRs/CreditMemoRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("CreditMemoRet", {})

    qbd_credit_memo_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_credit_memo_create_credit_memo_sub_steps(qbd_hash)
    qbd_credit_memo_find_or_assign_associated_opts(qbd_hash)
    if self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
      qbd_credit_memo_hash_to_credit_memo(qbd_hash)
    end
  end

  def qbd_credit_memo_hash_to_credit_memo(qbd_hash, credit_memo = nil)
    if credit_memo.nil?
      credit_memo = qbd_credit_memo_find_by_name(qbd_hash.fetch('RefNumber', nil))
      credit_memo ||= self.company.credit_memos.new(
        channel: 'qbd',
        number: Spree::CreditMemo.number_from_integration(qbd_hash.fetch('RefNumber', nil), self.company.id),
        currency: self.company.try(:currency)
      )
    end
    #Set Date Fields
    credit_memo_date = qbd_hash.fetch('TxnDate', Time.current).to_date
    credit_memo.txn_date = credit_memo_date
    credit_memo.note = qbd_hash.fetch('Memo', nil)
    credit_memo.additional_tax_total = qbd_hash.fetch('SalesTaxTotal', 0)
    #Set customer, line_items, shipping_method
    transaction do
      qbd_credit_memo_find_or_assign_associated_opts(qbd_hash, credit_memo)
      credit_memo.save!
    end

    qbd_create_or_update_match(credit_memo,
                              'Spree::CreditMemo',
                              qbd_hash.fetch('TxnID'),
                              'CreditMemo',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
  end

  def qbd_credit_memo_find_or_assign_associated_opts(qbd_hash, credit_memo = nil)
    account = qbd_find_account_by_id_or_name(qbd_hash, 'CustomerRef')
    credit_memo_txn_class = qbd_find_transaction_class_by_id_or_name(qbd_hash, 'ClassRef')
    shipping_method = qbd_find_shipping_method_by_id_or_name(qbd_hash, 'ShipMethodRef')
    tax_rate = qbd_find_tax_rate_by_id_or_name(qbd_hash, 'ItemSalesTaxRef')
    errors = []
    lines = []
    shipping_cost = 0
    # adjustment_total = 0
    [qbd_hash.fetch('CreditMemoLineRet', [])].flatten.each do |txn_line|
      begin
        item_name = txn_line.fetch('ItemRef', {}).fetch('FullName', nil)
        item_name ||= txn_line.fetch('ItemRef', {}).fetch('Name', nil)
        next if item_name.blank?
        next if self.integration_item.qbd_ignore_items.include?(item_name)
        tax_category = qbd_find_tax_category_by_id_or_name(txn_line, 'SalesTaxCodeRef')
        if item_name == self.integration_item.qbd_shipping_item_name
          shipping_cost += txn_line.fetch('Amount', 0).to_d
        else
          line_item = qbd_txn_line_to_line_item(txn_line, credit_memo)
          lines << line_item if line_item.present?
        end
      rescue Exception => e
        errors << e.message
      end
    end #end txn_line loop

    if self.integration_item.try(:qbd_ungroup_grouped_lines)
      [qbd_hash.fetch('CreditMemoLineGroupRet', [])].flatten.each do |group_line|
        [group_line.fetch('CreditMemoLineRet', [])].flatten.each do |txn_line|
          begin
            item_name = txn_line.fetch('ItemRef', {}).fetch('FullName', nil)
            item_name ||= txn_line.fetch('ItemRef', {}).fetch('Name', nil)
            next if item_name.blank?
            next if self.integration_item.qbd_ignore_items.include?(item_name)
            tax_category = qbd_find_tax_category_by_id_or_name(txn_line, 'SalesTaxCodeRef')
            if item_name == self.integration_item.qbd_shipping_item_name
              shipping_cost += txn_line.fetch('Amount', 0).to_d
            else
              line_item = qbd_txn_line_to_line_item(txn_line, credit_memo)
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
    if credit_memo.present?
      if account.nil?
        raise "Unable to find customer #{qbd_hash.fetch('CustomerRef', {}).fetch('FullName', nil)} for Credit Memo TxnID: #{qbd_hash.fetch('TxnID', nil)} / RefNumber: #{qbd_hash.fetch('RefNumber', nil)}"
      end
      credit_memo.account = account
      credit_memo.txn_class_id = credit_memo_txn_class.try(:id)
      credit_memo.shipping_method_id = shipping_method.try(:id)
      credit_memo.shipment_total = shipping_cost
    end
  end

  def qbd_credit_memo_query_xml(xml)
    xml.IncludeLineItems true
    xml.IncludeLinkedTxns true
  end

  def qbd_credit_memo_create(qbd_hash, qbxml_class)
    Sidekiq::Client.push(
      'class' => PullObjectWorker,
      'queue' => 'integrations',
      'args' => [
        self.integration_item_id,
        'Spree::CreditMemo',
        qbxml_class,
        qbd_hash.fetch('TxnID'),
        qbd_hash.fetch('RefNumber', nil)
      ]
    )

    return
  end

  def qbd_create_credit_memo_callback_steps(credit_memo_id)
    return unless self.integration_item.qbd_use_external_balance
    credit_memo_hash = self.company.credit_memos.friendly.find(credit_memo_id).to_integration
    # qbd_create_step(
    #   self.qbd_account_step(credit_memo_hash.fetch(:account_id), current_step.try(:id)).merge(force_create: true)
    # )

    self.company
        .customer_accounts
        .find_by_id(credit_memo_hash.fetch(:account_id))
        .try(:notify_integration)
  end

  def qbd_credit_memo_pull_step_hash(credit_memo_id = nil)
    { step_type: :pull, object_id: credit_memo_id, object_class: 'Spree::CreditMemo', qbxml_class: 'CreditMemo', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
  end
  def qbd_credit_memo_push_step_hash
    { step_type: :push, object_id: credit_memo_id, object_class: 'Spree::CreditMemo', qbxml_class: 'CreditMemo', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
  end
end
