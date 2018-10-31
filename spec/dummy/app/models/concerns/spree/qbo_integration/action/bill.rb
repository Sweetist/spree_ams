module Spree::QboIntegration::Action::Bill
  def qbo_synchronize_bill(order_id, order_class)
    order = self.company.purchase_orders.find(order_id)
    order_hash = order.to_integration(
        self.integration_item.integrationable_options_for(order)
      )
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: order_id,
      integration_syncable_type: order_class,
      sync_type: "Quickbooks::Model::Bill"
    )
    service = self.integration_item.qbo_service('Bill')
    puts '-----------'
    puts "SYNC ACCOUNT FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    sync_vendor = self.qbo_synchronize_vendor(order_hash.fetch(:account_id), 'Spree::Account')
    if sync_vendor.fetch(:status) == 10
      vendor_match = self.integration_item.integration_sync_matches.find_by(
        integration_syncable_id: order_hash.fetch(:account_id),
        integration_syncable_type: 'Spree::Account'
      )
      qbo_vendor_id = vendor_match.try(:sync_id)
    else
      return sync_vendor
    end

    if match.sync_id
      # we have match, push data
      qbo_bill = service.fetch_by_id(match.sync_id)
      qbo_update_bill(order_hash, qbo_bill, service, qbo_vendor_id)
    else
      # try to match by name
      qbo_bill = service.query("
        select * from Bill
        where DocNumber='#{self.qbo_safe_string(order_hash.fetch(:fully_qualified_name))}'
      ").first
      if qbo_bill
        if( self.integration_item.qbo_include_department &&
            self.integration_item.qbo_enforce_channel &&
            qbo_order.try(:department_ref).try(:name) != order_hash.fetch(:channel)
          )
          raise Exception.new("Bill with number #{order_hash.fetch(:number)} already exists in Quickbooks.")
        end
        match.sync_id = qbo_bill.id
        match.sync_type = qbo_bill.class.to_s
        match.save
        qbo_update_bill(order_hash, qbo_bill, service, qbo_vendor_id)
      else
        # no match, create new!
        qbo_new_bill = qbo_bill_to_qbo_bill(Quickbooks::Model::Bill.new, order_hash, qbo_vendor_id)

        if qbo_new_bill.class == Hash
          return qbo_new_bill
        else
          response = service.create(qbo_new_bill)
          match.sync_id = response.id
          match.sync_type = response.class.to_s
          match.save
          { status: 10, log: "#{order_hash.fetch(:po_name_for_integration)} => Pushed." }
        end
      end
    end
  rescue Exception => e
    Airbrake.notify(
      error_message: "#{e.class.to_s} - #{e.message}",
      error_class: "QBO Order Sync"
    )
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_update_bill(order_hash, qbo_bill, service, qbo_vendor_id)
    if ['void', 'canceled', 'cancelled'].include?(order_hash.fetch(:state))
      service.delete(qbo_bill)
    else
      qbo_updated_bill = qbo_bill_to_qbo_bill(qbo_bill, order_hash, qbo_vendor_id)
      if qbo_updated_bill.class == Hash
        return qbo_updated_bill
      else
        puts '-----------'
        puts "CALL QBO SERVICE FOR ORDER #{order_hash.fetch(:number)}"
        puts '-----------'
        service.update(qbo_updated_bill)
      end
    end
    { status: 10, log: "#{order_hash.fetch(:po_name_for_integration)} => Match updated in QBO." }
  end

  def qbo_bill_to_qbo_bill(qbo_bill, order_hash, qbo_vendor_id)
    puts '-----------'
    puts "BEGIN QBO ORDER MAPPING FOR #{order_hash.fetch(:number)}"
    puts '-----------'
    qbo_bill.txn_date = order_hash.fetch(:invoice_date)
    qbo_bill.doc_number = order_hash.fetch(:po_number)

    if integration_item.qbo_multi_currency
      qbo_bill.currency_ref = Quickbooks::Model::BaseReference.new(order_hash.fetch(:currency))
      qbo_bill.exchange_rate = qbo_exchange_rate(order_hash.fetch(:currency)) # Need to supply an exchange rate for multi-currency
    end

    if self.integration_item.qbo_include_department
      puts '-----------'
      puts "MAPPING QBO DEPARTMENT FOR ORDER #{order_hash.fetch(:number)}"
      puts '-----------'
      department_service = self.integration_item.qbo_service('Department')
      qbo_department = department_service.query("select * from Department where FullyQualifiedName='#{order_hash.fetch(:channel)}'").first
      if qbo_department.nil?
        new_department = Quickbooks::Model::Department.new
        new_department.name = order_hash.fetch(:channel, '')
        qbo_department = department_service.create(new_department)
      end

      qbo_bill.department_ref = Quickbooks::Model::BaseReference.new(qbo_department.try(:id))
    end

    # Vendor
    puts '-----------'
    puts "MAPPING QBO VENDOR ID FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    qbo_bill.vendor_ref = Quickbooks::Model::BaseReference.new(qbo_vendor_id)
    puts '-----------'
    puts "BEGIN MAPPING QBO LINE ITEMS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    # Line Items
    qbo_bill.line_items = []
    order_hash.fetch(:line_items, []).each_with_index do |line_item_hash, index|
      qbo_line_item = Quickbooks::Model::BillLineItem.new
      qbo_line_item.amount = line_item_hash.fetch(:amount)

      qbo_line_item.description = qbo_bill_line_description(line_item_hash)

      qbo_line_item.detail_type = 'ItemBasedExpenseLineDetail'
      qbo_bill.line_items << qbo_item_based_expense_item_line_detail(qbo_bill, qbo_line_item, line_item_hash, index)
    end
    puts '-----------'
    puts "ENDMAPPING QBO LINE ITEMS FOR ORDER #{order_hash.fetch(:number)}"
    # puts "BEGIN MAPPING QBO SHIPPING FOR ORDER #{order_hash.fetch(:number)}"
    # puts '-----------'
    # # Shipping -- send shipping if feature enabled
    # if self.integration_item.qbo_include_shipping && order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
    #   qbo_bill.ship_method_ref = Quickbooks::Model::BaseReference.new(order_hash.fetch(:shipping_method, {}).fetch(:name), name: order_hash.fetch(:shipping_method, {}).fetch(:name))
    #   ship_item = Quickbooks::Model::InvoiceLineItem.new
    #   ship_item.amount = order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
    #   ship_item.sales_item! do |detail|
    #     detail.item_ref = Quickbooks::Model::BaseReference.new('SHIPPING_ITEM_ID')
    #   end
    #   qbo_bill.line_items << ship_item
    # end
    # Discounts
    # puts '-----------'
    # puts "MAPPING QBO DISCOUNTS FOR ORDER #{order_hash.fetch(:number)}"
    # puts '-----------'
    # if self.integration_item.qbo_include_discounts
    #   qbo_discount_item = qbo_bill_discount(order_hash)
    #   qbo_bill.line_items << qbo_discount_item
    # end
    # PO Number

    account = Spree::Account.find(order_hash.fetch(:account_id))
    #BillAddress
    puts '-----------'
    puts "MAPPING QBO BILL ADDRESS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    bill_address = account.bill_address
    vendor_address_hash = bill_address.try(
        :to_integration,
        self.integration_item.integrationable_options_for(bill_address)
      ) || {}
    qbo_bill.remit_to_address = self.qbo_address_to_qbo(Quickbooks::Model::PhysicalAddress.new, vendor_address_hash, true)

    #ShipAddress
    puts '-----------'
    puts "MAPPING QBO SHIP ADDRESS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    location = self.company.stock_locations.find_by_id(order_hash.fetch(:po_stock_location_id, nil))
    if location
      shipping_address_hash = location.to_integration(
          self.integration_item.integrationable_options_for(location)
        )
      qbo_bill.shipping_address = self.qbo_address_to_qbo(Quickbooks::Model::PhysicalAddress.new, shipping_address_hash, true)
    end
    # Vendor Memo
    puts '-----------'
    puts "MAPPING QBO VENDOR MEMO FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    # TODO update ruby-quickbooks to support sending memo
    # qbo_bill.memo = order_hash.fetch(:special_instructions)
    puts '-----------'
    puts "FINISH MAPPING ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    qbo_bill
  end

  def qbo_bill_line_description(item_hash)
    description = item_hash.fetch(self.integration_item.qbo_send_to_line_description.to_sym)
    if integration_item.qbo_include_lots && item_hash.fetch(:lot_number).present?
      description += "\n#{item_hash.fetch(:lot_number)}"
    end

    ActionView::Base.full_sanitizer.sanitize(qbo_safe_string(description))
  end

  def qbo_item_based_expense_item_line_detail(qbo_order, qbo_line_item, line_item_hash, index)
    qbo_line_item.item_based_expense_item! do |detail|
      puts '-----------'
      puts "SYNCING VARIANT #{line_item_hash.fetch(:fully_qualified_description,'')}"
      puts '-----------'
      sync_variant = self.qbo_synchronize_variant(line_item_hash.fetch(:variant_id), 'Spree::Variant')
      puts '-----------'
      puts "FINISH SYNCING VARIANT"
      puts '-----------'
      if sync_variant.fetch(:status) == 10
        variant = self.integration_item.integration_sync_matches.find_by(
          integration_syncable_id: line_item_hash.fetch(:variant_id),
          integration_syncable_type: 'Spree::Variant'
        )
        detail.item_ref = Quickbooks::Model::BaseReference.new(variant.try(:sync_id))
      else
        raise Exception.new("#{line_item_hash.fetch(:item_name,'').strip} #{sync_variant.fetch(:log, "An error occured while syncing a product")}")
        # return sync_variant
      end
      detail.unit_price = line_item_hash.fetch(:discount_price)
      detail.quantity = line_item_hash.fetch(:quantity)
      if line_item_hash.fetch(:adjustments, {}).fetch(:is_tax_present) || self.integration_item.qbo_country != 'US'
        detail.tax_code_ref = Quickbooks::Model::BaseReference.new('TAX')
        qbo_tax_code = self.qbo_synchronize_tax_category(line_item_hash.fetch(:tax_category_id))
        if self.integration_item.qbo_country == 'US'
          detail.tax_code_ref = Quickbooks::Model::BaseReference.new('TAX')
        else
          detail.tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
        end
        tax_line_detail = Quickbooks::Model::TaxLineDetail.new
        tax_line_detail.tax_rate_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.sales_tax_rate_list.tax_rate_detail.first.tax_rate_ref.value)
        tax_line = Quickbooks::Model::TaxLine.new
        tax_line.detail_type = 'TaxLineDetail'
        tax_line.line_num = index + 1
        tax_line.tax_line_detail = tax_line_detail
        qbo_order.txn_tax_detail.lines << tax_line
        qbo_order.txn_tax_detail.txn_tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
      else
        detail.tax_code_ref = Quickbooks::Model::BaseReference.new('NON')
      end
    end

    qbo_line_item
  end

  def qbo_delete_bill(order_id)
    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_id: order_id,
      integration_syncable_type: 'Spree::Order',
      sync_type: "Quickbooks::Model::Bill"
    ).first

    return unless match.try(:sync_id)
    service = self.integration_item.qbo_service('Bill')
    qbo_bill = service.fetch_by_id(match.sync_id)

    service.delete(qbo_bill) if qbo_bill
  end
end
