module Spree::Integrationable
  def to_integration(options = {})
    self.method("to_integration_from_#{self.class.name.demodulize.underscore}").call(options)
  end

  def from_integration(hash, options = {})
    self.method("from_integration_to_#{self.class.name.demodulize.underscore}").call(hash, options) rescue false
  end

  private
  #
  # Order
  #
  def to_integration_from_order(options)
    order_account = options[:customer] || self.account
    {
      self: self,
      id: self.id,
      name_for_integration: self.name_for_integration,
      email: self.valid_emails_string,
      po_name_for_integration: self.po_name_for_integration,
      fully_qualified_name: self.invoice.try(:multi_order) ? self.display_number : self.invoice.try(:number) || self.display_number,
      currency: self.currency,
      item_total: self.item_total,
      adjustment_total: self.adjustment_total,
      completed_at: self.completed_at,
      updated_at: self.updated_at,
      approved_at: self.approved_at,
      state: self.state,
      number: self.invoice.try(:multi_order) ? self.display_number : self.invoice.try(:number) || self.display_number,
      channel: self.channel.to_s.titleize,
      delivery_date: self.delivery_date,
      due_date: self.due_date,
      invoice_date: self.invoice_date,
      account_id: order_account.try(:id),
      po_number: self.po_display_number,
      rep: self.account.try(:rep).try(:name),
      override_shipment_cost: self.override_shipment_cost,
      shipment_total: self.shipment_total,
      shipping_method_id: self.shipping_method_id,
      special_instructions: self.special_instructions,
      txn_class_id: self.vendor.track_order_class? ? self.txn_class_id : nil,
      payment_term_id: self.account.try(:payment_terms_id),
      bill_address: self.bill_address,
      ship_address: self.ship_address,
      custom_attrs: self.custom_attrs,
      line_items: self.line_items.joins(:variant).reorder(
        Spree::LineItem.company_sort(self.vendor, options[:line_item_sort])
      ).map { |item|
        {
          self: item,
          id: item.id,
          item_name: item.item_name,
          item_type: item.variant.variant_or_product_type,
          amount: item.amount,
          fully_qualified_description: item.item_name,
          pack_size: item.pack_size,
          sku: item.try(:sku),
          variant_description: item.variant.is_master? ? item.product.description : item.variant.variant_description,
          track_lots: item.variant.should_track_lots?,
          lot_number: item.display_lot_with_parts_number({sparse: true, prefix: "Lot(qty): "}),
          top_level_lot: item.line_item_lots_text(item.line_item_lots_for(item.variant), {sparse: true, prefix: "Lot(qty): "}),
          variant_id: item.variant_id,
          discount_price: item.discount_price,
          quantity: item.quantity,
          tax_category_id: item.tax_category_id || item.variant.tax_category_id,
          txn_class_id: self.vendor.track_line_item_class? ? item.txn_class_id : nil,
          stock_location_id: item.inventory_units.first.try(:shipment).try(:stock_location_id) || self.vendor.default_stock_location.try(:id) || self.vendor.stock_locations.first.try(:id),
          adjustments: {
            is_tax_present: item.adjustments.tax.present?
          },
          parts_variants: item.variant.parts_variants.map { |part_variant|
            discount_price = (Spree::AccountViewableVariant.where(account_id: self.account_id, variant_id: part_variant.part_id).first.try(:price) || part_variant.part.price).to_d
            part = part_variant.part
            {
              part_id: part.id,
              count: part_variant.count,
              part: part_variant.part.to_integration,
              item_name: part.fully_qualified_name,
              item_type: part.variant_or_product_type,
              amount: discount_price * part_variant.count.to_f * item.quantity,
              fully_qualified_description: part.fully_qualified_name,
              pack_size: part.pack_size,
              sku: part.sku,
              variant_description: part.try(:is_master?) ? part.try(:product).try(:description) : part.try(:variant_description),
              lot_number: item.line_item_lots_text(item.line_item_lots_for(part_variant.part), {sparse: true, prefix: "Lot(qty): "}),
              top_level_lot: item.line_item_lots_text(item.line_item_lots_for(part_variant.part), {sparse: true, prefix: "Lot(qty): "}),
              variant_id: part_variant.part_id,
              discount_price: discount_price,
              quantity: part_variant.count.to_f * item.quantity,
              tax_category_id: part.tax_category_id,
              txn_class_id: self.vendor.track_line_item_class? ? item.txn_class_id : nil,
              stock_location_id: item.inventory_units.first.try(:shipment).try(:stock_location_id) || self.vendor.default_stock_location.try(:id) || self.vendor.stock_locations.first.try(:id),
              adjustments: {
                #TODO identify if the part is taxable
                is_tax_present: item.adjustments.tax.present?
              }
            }
          }
        }
      },
      shipping_method: {
        name: self.shipping_method.try(:name) || 'Shipping',
        item_name: "Shipping", # hard-code of shipping charge to sync to a "Shipping" item in QBD
        shipment_total: self.shipment_total,
        tax_category_id: self.shipping_method.try(:tax_category_id),
        additional_tax_total: self.shipments.sum(:additional_tax_total).to_d,
        included_tax_total: self.shipments.sum(:included_tax_total).to_d,
        shipping_account_id: self.vendor.chart_accounts.where(chart_account_category_id: Spree::ChartAccountCategory.where(name: 'Shipping Account').first.try(:id)).first.try(:id)
      },
      adjustments: {
        sum: self.adjustment_total - self.additional_tax_total - self.included_tax_total,
        discount_account_id: self.vendor.chart_accounts.where(chart_account_category_id: Spree::ChartAccountCategory.where(name: 'Discount Account').first.try(:id)).first.try(:id),
        line_items: (self.all_adjustments.eligible - self.all_adjustments.tax).map { |item|
          {
            name: item.try(:source) ? item.try(:source).try(:promotion).try(:name) : item.try(:label),
            amount: item.try(:amount)
          }
        }
      },
      shipments: self.shipments.map { |shipment|
        {
          id: shipment.try(:id),
          tracking: shipment.try(:tracking),
          number: shipment.try(:number),
          state: shipment.try(:state),
          stock_location_id: shipment.try(:stock_location_id),
          line_items: shipment.line_items.map { |item|
            {
              self: item,
              id: item.id,
              item_name: item.item_name,
              item_type: item.variant.variant_or_product_type,
              amount: item.amount,
              lot_number: item.display_lot_with_parts_number({sparse: true, prefix: "Lot(qty): "}),
              top_level_lot: item.line_item_lots_text(item.line_item_lots_for(item.variant), {sparse: false, prefix: "Lot(qty): "}),
              fully_qualified_description: item.item_name,
              variant_id: item.variant_id,
              discount_price: item.discount_price,
              quantity: item.quantity,
              tax_category_id: item.tax_category_id || item.variant.tax_category_id,
              stock_location_id: shipment.try(:stock_location_id),
              adjustments: {
                is_tax_present: item.adjustments.tax.present?
              }
            }
          }
        }
      }
    }
  end

  def to_integration_from_credit_memo(options)
    customer_account = options[:customer] || self.try(:account)
    {
      id: self.id,
      name_for_integration: self.name_for_integration,
      vendor_id: self.vendor_id,
      account_id: customer_account.try(:id),
      number: self.number,
      total: self.total,
      item_total: self.item_total,
      additional_tax_total: self.additional_tax_total,
      included_tax_total: self.included_tax_total,
      shipment_total: self.shipment_total,
      amount_remaining: self.amount_remaining,
      created_at: self.created_at,
      updated_at: self.updated_at,
      currency: self.currency || self.vendor.try(:currency),
      txn_class_id: self.vendor.track_order_class? ? self.txn_class_id : nil,
      bill_address: customer_account.try(:bill_address),
      ship_address: customer_account.try(:default_ship_address),
      note: self.try(:note),
      line_items: self.credit_line_items.joins(:variant).reorder(
        Spree::LineItem.company_sort(self.vendor, options[:line_item_sort])
      ).map { |item|
        {
          self: item,
          id: item.id,
          item_name: item.item_name,
          item_type: item.variant.variant_or_product_type,
          amount: item.amount,
          fully_qualified_description: item.item_name,
          variant_id: item.variant_id,
          discount_price: item.discount_price,
          quantity: item.quantity,
          tax_category_id: item.tax_category_id || item.variant.tax_category_id,
          txn_class_id: self.vendor.track_line_item_class? ? item.txn_class_id : nil,
          stock_location_id: item.inventory_units.first.try(:shipment).try(:stock_location_id) || self.vendor.default_stock_location.try(:id) || self.vendor.stock_locations.first.try(:id),
          adjustments: {
            is_tax_present: item.adjustments.tax.present?
          },
          parts_variants: item.variant.parts_variants.map { |part_variant|
            discount_price = (Spree::AccountViewableVariant.where(account_id: self.account_id, variant_id: part_variant.part_id).first.try(:price) || part_variant.part.price).to_d
            part = part_variant.part
            {
              part_id: part.id,
              count: part_variant.count,
              part: part_variant.part.to_integration,
              item_name: part.fully_qualified_name,
              item_type: part.variant_or_product_type,
              amount: discount_price * part_variant.count.to_f * item.quantity,
              fully_qualified_description: part.fully_qualified_name,
              variant_id: part_variant.part_id,
              discount_price: discount_price,
              quantity: part_variant.count.to_f * item.quantity,
              tax_category_id: part.tax_category_id,
              txn_class_id: self.vendor.track_line_item_class? ? item.txn_class_id : nil,
              stock_location_id: item.inventory_units.first.try(:shipment).try(:stock_location_id) || self.vendor.default_stock_location.try(:id) || self.vendor.stock_locations.first.try(:id),
              adjustments: {
                #TODO identify if the part is taxable
                is_tax_present: item.adjustments.tax.present?
              }
            }
          }
        }
      },
    }
  end

  def to_integration_from_payment(options)
    pm = self.payment_method
    payment_account = options[:customer] || self.order.try(:account)
    refund_amt = self.refunds.where(reimbursement_id: nil).sum(:amount) || 0
    {
      id: self.id,
      name_for_integration: self.name_for_integration,
      created_at: self.created_at,
      currency: self.try(:currency) || self.vendor.try(:currency),
      amount: self.amount - refund_amt,
      order_id: self.order_id,
      account_id: payment_account.try(:id),
      source_id: self.source_id,
      source_type: self.source_type,
      source: self.source,
      state: self.state,
      number: self.number,
      fully_qualified_name: self.number,
      ref_number: self.txn_id.present? ? self.txn_id : self.number,
      memo: self.memo,
      txn_id: self.txn_id,
      currency: self.order.try(:currency),
      payment_method_id: pm.try(:id),
      payment_method: {
        id: pm.try(:id),
        type: pm.try(:type),
        name: pm.try(:name),
        fully_qualified_name: pm.try(:name),
        description: pm.try(:description),
        active: pm.try(:active),
        credit_card: pm.try(:credit_card?)
      }
    }
  end

  def to_integration_from_account_payment(options)
    pm = self.payment_method
    payment_account = options[:customer] || self.account
    refund_amt = self.refunds.where(reimbursement_id: nil).sum(:amount) || 0
    inner_payments = self.payments.completed.map do |payment|
      refund_amt = payment.refunds.where(reimbursement_id: nil).sum(:amount) || 0
      {
        order_id: payment.order_id,
        amount: payment.amount - refund_amt,
        state: payment.state
      }
    end
    {
      id: self.id,
      name_for_integration: self.name_for_integration,
      created_at: self.created_at,
      payment_date: self.payment_date,
      currency: self.try(:currency) || self.vendor.try(:currency),
      amount: self.amount - refund_amt,
      amount_to_credit: (self.amount - refund_amt) - inner_payments.inject(0){|sum, p| p.fetch(:amount, 0)},
      order_ids: self.order_ids,
      inner_payments: inner_payments,
      account_id: payment_account.try(:id),
      source_id: self.source_id,
      source_type: self.source_type,
      source: self.source,
      state: self.state,
      number: self.number,
      fully_qualified_name: self.number,
      ref_number: self.txn_id.present? ? self.txn_id : self.display_number,
      memo: self.memo,
      txn_id: self.txn_id,
      currency: self.vendor.try(:currency),
      payment_method_id: pm.try(:id),
      payment_method: {
        id: pm.try(:id),
        type: pm.try(:type),
        name: pm.try(:name),
        fully_qualified_name: pm.try(:name),
        description: pm.try(:description),
        active: pm.try(:active),
        credit_card: pm.try(:credit_card?)
      }
    }
  end

  def to_integration_from_payment_method(options)
    {
      id: self.id,
      type: self.type,
      name: self.name,
      fully_qualified_name: self.name,
      description: self.description,
      active: self.active,
      credit_card: self.try(:credit_card?)
    }
  end

  def to_integration_from_refund(options)
    {
      id: self.id,
      name_for_integration: self.name_for_integration,
      payment: self.payment.try(:to_integration) || {}
    }
  end

  def from_integration_to_order(hash, options)
    false
  end

  #
  # Account
  #
  def to_integration_from_account(options)
    {
      fully_qualified_name: self.fully_qualified_name,
      account: {
        self: self,
        id: self.id,
        name_for_integration: self.name_for_integration,
        active: self.active?,
        number: self.number,
        credit_limit: self.credit_limit,
        name: self.name,
        txn_class_id: self.default_txn_class_id,
        fully_qualified_name: self.fully_qualified_name,
        display_name: self.try(:display_name),
        email: self.valid_emails_string,
        customer_type_id: self.customer_type_id,
        rep_id: self.rep_id,
        taxable: self.taxable,
        payment_term_id: self.payment_terms_id,
        firstname: self.primary_cust_contact.try(:first_name).to_s,
        lastname: self.primary_cust_contact.try(:last_name).to_s,
        sub_customer: self.parent_account.present?,
        parent_id: self.parent_id,
        billing_address: self.bill_address,
        shipping_address: self.default_ship_address
      },
      parent_account: {
        self: self.parent_account,
        id: self.parent_id,
        name_for_integration: self.parent_account.try(:name_for_integration),
        active: self.parent_account.try(:active?),
        number: self.parent_account.try(:number),
        name: self.parent_account.try(:name),
        fully_qualified_name: self.parent_account.try(:fully_qualified_name),
        email: self.parent_account.try(:valid_emails_string),
        customer_type_id: self.parent_account.try(:customer_type_id),
        rep_id: self.parent_account.try(:rep_id),
        payment_term_id: self.parent_account.try(:payment_terms_id),
        firstname: self.parent_account.try(:primary_cust_contact).try(:first_name).to_s,
        lastname: self.parent_account.try(:primary_cust_contact).try(:last_name).to_s,
        sub_customer: self.parent_account.try(:parent_account).present?,
        parent_id: self.parent_account.try(:parent_id),
        billing_address: self.parent_account.try(:bill_address),
        shipping_address: self.parent_account.try(:default_ship_address)
      },
      customer: {
        name_for_integration: self.customer.name_for_integration,
        company_id: self.customer_id,
        firstname: self.customer.users.first.try(:firstname).to_s,
        lastname: self.customer.users.first.try(:lastname).to_s,
        name: self.customer.try(:name),
        email: self.customer.try(:valid_emails_string)
      },
      ship_address: {
        firstname: self.default_ship_address.try(:firstname),
        lastname: self.default_ship_address.try(:lastname),
        company: self.default_ship_address.try(:company) || self.fully_qualified_name,
        address1: self.default_ship_address.try(:address1),
        address2: self.default_ship_address.try(:address2),
        city: self.default_ship_address.try(:city),
        country_id: self.default_ship_address.try(:country_id),
        zipcode: self.default_ship_address.try(:zipcode),
        state_id: self.default_ship_address.try(:state_id),
        phone: self.default_ship_address.try(:phone)
      },
      bill_address: {
        firstname: self.bill_address.try(:firstname),
        lastname: self.bill_address.try(:lastname),
        company: self.bill_address.try(:company) || self.fully_qualified_name,
        address1: self.bill_address.try(:address1),
        address2: self.bill_address.try(:address2),
        city: self.bill_address.try(:city),
        country_id: self.bill_address.try(:country_id),
        zipcode: self.bill_address.try(:zipcode),
        state_id: self.bill_address.try(:state_id),
        phone: self.bill_address.try(:phone)
      }
    }
  end

  def from_integration_to_account(hash, options)
    self.try(:update_columns, hash.fetch(:account, {}))
    self.customer.try(:update_columns, hash.fetch(:customer, {})) #need to remove this after fixing qbd
    self.default_ship_address.try(:update_columns, hash.fetch(:ship_address, {}))
    self.bill_address.try(:update_columns, hash.fetch(:bill_address, {}))
  end

  #
  # Address
  #
  def to_integration_from_address(options)
    {
      firstname: self.firstname,
      lastname: self.lastname,
      company: self.company,
      address1: self.address1,
      address2: self.address2,
      city: self.city,
      country_id: self.country_id,
      zipcode: self.zipcode,
      state_id: self.state_id,
      state_name: self.state.try(:name),
      phone: self.phone
    }
  end


  def to_integration_from_stock_location(options)
    {
      self: self,
      name_for_integration: self.name,
      fully_qualified_name: self.name,
      name: self.name,
      company: self.vendor.name,
      address1: self.address1,
      address2: self.address2,
      city: self.city,
      country_id: self.country_id,
      zipcode: self.zipcode,
      state_id: self.state_id,
      state_name: self.state.try(:name),
      phone: self.phone
    }
  end

  def from_integration_to_stock_location(hash, options)
    self.try(:update_columns, hash)
  end

  #
  # Payment Term
  #
  def to_integration_from_payment_term(options)
    {
      self: self,
      id: self.id,
      name_for_integration: self.name,
      fully_qualified_name: self.name,
      due_in_days: self.num_days,
      name: self.name
    }
  end

  def from_integration_to_payment_term(hash, options)
    # payment terms are shared, so we don't want to update anything here
    # self.try(:update_columns, hash)
  end

  #
  # Customer Type
  #
  def to_integration_from_customer_type(options)
    name_parts = self.name.split(':')

    {
      self: self,
      id: self.id,
      name_for_integration: self.name,
      fully_qualified_name: self.name,
      name: name_parts.last.try(:strip),
      parent_name: name_parts[-2].try(:strip),
      parent_fully_qualifed_name: name_parts[0..-2].join(':')
    }
  end

  def from_integration_to_customer_type(hash, options)
    self.try(:update_columns, hash)
  end

  #
  # Rep
  #
  def to_integration_from_rep(options)
    {
      self: self,
      id: self.id,
      name_for_integration: self.name,
      fully_qualified_name: self.name,
      initials: self.initials,
      name: self.name
    }
  end

  def from_integration_to_rep(hash, options)
    self.try(:update_columns, hash)
  end

  #
  # Tax Rate
  #
  def to_integration_from_tax_rate(options)
    {
      self: self,
      name_for_integration: self.name,
      fully_qualified_name: self.name,
      name: self.name,
      zone_name: self.zone.try(:name),
      amount: self.amount,
      tax_category_id: self.tax_category_id
    }
  end

  def from_integration_to_tax_rate(hash, options)
    self.try(:update_columns, hash)
  end

  #
  # Tax Category
  #
  def to_integration_from_tax_category(options)
    {
      self: self,
      name_for_integration: self.name,
      fully_qualified_name: self.tax_code,
      name: self.name,
      code: self.tax_code,
      description: self.description,
      tax_rates: self.tax_rates.map { |tax_rate|
        {
          self: tax_rate,
          id: tax_rate.id,
          name: tax_rate.name,
          amount: tax_rate.amount
        }
      }
    }
  end

  def from_integration_to_tax_category(hash, options)
    self.try(:update_columns, hash)
  end

  #
  # Stock Transfer
  #
  def to_integration_from_stock_transfer(options)
    # if self.transfer_type == 'build'
    #   assembly = self.stock_movements.where('quantity > ?', 0).first.try(:stock_item).try(:variant)
    #   gen_account_id = assembly.try(:general_account_id) || assembly.try(:asset_account_id) || assembly.try(:cogs_account_id) || assembly.try(:income_account_id) || assembly.try(:expense_account_id)
    # else
    #   gen_account_id = self.general_account_id
    # end
    {
      self: self,
      id: self.id,
      name_for_integration: self.number,
      fully_qualified_name: self.number,
      number: self.number,
      memo: self.reference,
      note: self.note,
      transfer_type: self.transfer_type,
      general_account_id: self.general_account_id,
      source_location_id: self.source_location_id,
      destination_location_id: self.destination_location_id,
      source_items: self.stock_movements.joins(:stock_item).where('spree_stock_items.stock_location_id = ?', self.source_location_id).map { |stock_movement|
        {
          variant_id: stock_movement.stock_item.try(:variant_id),
          quantity: stock_movement.quantity
        }
      },
      destination_items: self.stock_movements.joins(:stock_item).where('spree_stock_items.stock_location_id = ?', self.destination_location_id).map { |stock_movement|
        {
          variant_id: stock_movement.stock_item.try(:variant_id),
          quantity: stock_movement.quantity
        }
      },
      created_at: self.created_at
    }
  end

  def from_integration_to_stock_transfer(hash, options)
    self.try(:update_columns, hash)
  end

  #
  # Stock Item
  #
  def to_integration_from_stock_item(options)
    {
      self: self,
      id: self.id,
      variant_id: self.variant_id,
      stock_location_id: self.stock_location_id,
      count_on_hand: self.count_on_hand,
      backorderable: self.backorderable
    }
  end

  def from_integration_to_stock_item(hash, options)
    self.try(:update_columns, hash)
  end

  #
  # Variant
  #
  def to_integration_from_variant(options)

    inventory_data = {
      variant_type: self.variant_or_product_type,
      general_account_id: self.general_account_id,
      income_account_id: self.income_account_id,
      cogs_account_id: self.cogs_account_id,
      asset_account_id: self.asset_account_id,
      expense_account_id: self.expense_account_id,
      total_on_hand: self.total_on_hand,
      inventory_counts: self.stock_items.map{ |stock_item|
        stock_item.to_integration
      }
    }

    name_parts = self.fully_qualified_name.split(':')

    {
      self: self,
      id: self.id,
      product_id: self.product_id,
      master: self.product.master,
      name_for_integration: self.name_for_integration,
      fully_qualified_name: self.fully_qualified_name,
      fully_qualified_sku: self.fully_qualified_sku,
      is_master: self.is_master?,
      is_sub_item: self.fully_qualified_name.include?(':'),
      name: name_parts.last.try(:strip) || self.product.name,
      parent_name: name_parts[-2].try(:strip),
      parent_fully_qualifed_name: name_parts[0..-2].join(':'),
      sku: self.sku,
      description: self.description_string,
      pack_size: self.pack_size,
      price: self.price,
      cost_price: self.current_cost_price,
      track_inventory: self.should_track_inventory?,
      txn_class_id: self.vendor.track_line_item_class? ? self.txn_class_id : nil,
      available_on: self.available_on,
      tax_category_id: self.tax_category_id,
      discontinued_on: self.discontinued_on,
      active: self.active?,
      for_sale: self.product.for_sale,
      for_purchase: self.product.for_purchase,
      custom_attrs: self.custom_attrs,
      product: {
        has_variants: self.product.has_variants?,
        name: self.product.name,
        description: self.product.description,
        available_on: self.product.available_on,
        slug: self.product.slug,
        meta_description: self.product.meta_description,
        meta_keywords: self.product.meta_keywords,
        tax_category_id: self.product.tax_category_id,
        shipping_category_id: self.product.shipping_category_id,
        promotionable: self.product.promotionable,
        meta_title: self.product.meta_title,
        vendor_id: self.product.vendor_id,
        discontinued_on: self.product.discontinued_on,
        active: self.product.active?,
        for_sale: self.product.for_sale,
        for_purchase: self.product.for_purchase,
        option_types: self.product.option_types.map do |ot|
          {
            id: ot.id,
            name: ot.name,
            presentation: ot.presentation
          }
        end
      },
      parts_variants: self.parts_variants.map do |part_variant|
        {
          part_id: part_variant.part_id,
          quantity: part_variant.count
        }
      end,
      option_values: self.ordered_option_values.includes(:option_type).map do |ov|
        {
          id: ov.id,
          name: ov.name,
          presentation: ov.presentation,
          option_type: {
            id: ov.option_type_id,
            name: ov.option_type.name,
            presentation: ov.option_type.presentation
          }
        }
      end
    }.merge(inventory_data)
  end

  def from_integration_to_variant(hash, options)
    variant_hash = hash.fetch(:variant, {})
    self.update_columns(variant_hash) unless variant_hash.empty?
    product_hash = hash.fetch(:product, {})
    self.product.update_columns(product_hash) unless product_hash.empty?
    price = self.default_price
    price.amount = hash.fetch(:price)
    price.save
    unless hash.fetch(:sub_item, {}).empty?
      old_option_value = self.option_values.first
      vendor = self.product.vendor
      option_value = vendor.option_values.where('name ILIKE ? AND option_type_id = ?', hash.fetch(:sub_item, {}).fetch(:name), old_option_value.try(:option_type_id)).first
      option_value ||= vendor.option_values.create(name: hash.fetch(:sub_item, {}).fetch(:name), presentation: hash.fetch(:sub_item, {}).fetch(:name).capitalize, option_type_id: old_option_value.try(:option_type_id))
      self.option_value_ids = [option_value.try(:id)].compact
    end
  end

  def to_integration_from_shipment(options)
    {
      tracking: self.tracking,
      number: self.number,
      cost: self.cost,
      shipped_at: self.shipped_at,
      state: self.state
    }
  end

  def to_itegration_from_line_item
    {
      self: self,
      product_name: self.product.name,
      price: self.price,
      currency: self.currency,
      discount_price: self.discount_price,
      amount: self.amount, # amount = total amount for the line
      lot_number: self.lot_number,
      fully_qualified_description: self.item_name,
      variant_id: self.variant_id,
      quantity: self.quantity,
      tax_category_id: self.tax_category_id || item.variant.tax_category_id,
      txn_class_id: self.order.try(:vendor).try(:track_line_item_class?) ? self.txn_class_id : nil,
      adjustments: {
        is_tax_present: self.adjustments.tax.present?
      }
    }
  end

  def to_integration_from_chart_account(options)
    name_parts = self.name.split(':')
    {
      self: self,
      id: self.id,
      name: self.name,
      parent_id: self.parent_id,
      name_for_integration: self.name_for_integration,
      fully_qualified_name: self.fully_qualified_name,
      account_type: self.chart_account_category.try(:name)
    }
  end

  def to_integration_from_transaction_class(options)
    name_parts = self.fully_qualified_name.split(':')
    {
      id: self.id,
      name_for_integration: self.name_for_integration,
      name: self.name,
      parent_id: self.parent_id,
      parent_name: name_parts[-2].try(:strip),
      parent_fully_qualifed_name: name_parts[0..-2].join(':'),
      fully_qualified_name: self.fully_qualified_name
    }
  end

  def to_integration_from_shipping_method(options)
    {
      name: self.name,
      fully_qualified_name: self.name
    }
  end
end
