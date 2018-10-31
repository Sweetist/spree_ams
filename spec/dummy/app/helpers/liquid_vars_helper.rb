module LiquidVarsHelper
  include Spree::CurrencyHelper
  include DateHelper

  def set_order_liquid_vars(order=nil)
    # if no order passed in, create sample data
    if order
      @order = order
    else
      create_sample_data

      unless @order.shipments
        @order.shipments << Spree::Shipment.last
      else
      end
    end
    {
      'my_company' =>
      {
        'name' => @order.try(:vendor).try(:name),
        'email' => @order.try(:vendor).try(:email)
      },
      'order' =>
      {
        'number' => @order.display_number,
        'po_number' => @order.try(:po_number),
        'url' => edit_order_url(@order, host: @order.vendor.domain, protocol: 'https'),
        'tracking_number' => @order.try(:shipments).try(:first).try(:tracking),
        'tracking_link' => @order.try(:shipments).try(:first).try(:tracking_url),
        'item_total' => display_sweet_price(@order.item_total, @order.vendor.currency).to_s,
        'total' => display_sweet_price(@order.total, @order.vendor.currency).to_s,
        'special_instructions' => @order.special_instructions,
        'delivery_date' => display_vendor_date_format(@order.delivery_date, @order.vendor.date_format),
        'invoice_date' => display_vendor_date_format(@order.invoice_date, @order.vendor.date_format),
        'invoice_due_date' => display_vendor_date_format(@order.due_date, @order.vendor.date_format),
        'customer' =>
        {
          'name' => @order.try(:account).try(:name),
          'display_name' => @order.try(:account).try(:default_display_name),
          'fully_qualified_name' => @order.try(:account).try(:fully_qualified_name),
          'email' => @order.try(:account).try(:email),
        },
        'bill_address' =>
          {
            'first_name' => @order.bill_address.try(:firstname),
            'last_name' => @order.bill_address.try(:lastname),
            'phone' => @order.bill_address.try(:phone),
            'company' => @order.bill_address.try(:company),
            'address1' => @order.bill_address.try(:address1),
            'address2' => @order.bill_address.try(:address2),
            'city' => @order.bill_address.try(:city),
            'state' => @order.bill_address.try(:state_name),
            'zip' => @order.bill_address.try(:zipcode),
            'country' => @order.bill_address.try(:country).try(:name)
          },
        'ship_address' =>
          {
            'first_name' => @order.ship_address.try(:firstname),
            'last_name' => @order.ship_address.try(:lastname),
            'phone' => @order.ship_address.try(:phone),
            'company' => @order.ship_address.try(:company),
            'address1' => @order.ship_address.try(:address1),
            'address2' => @order.ship_address.try(:address2),
            'city' => @order.ship_address.try(:city),
            'state' => @order.ship_address.try(:state_name),
            'zip' => @order.ship_address.try(:zipcode),
            'country' => @order.ship_address.try(:country).try(:name)
          }
      }
    }
  end

  def set_shipment_liquid_vars(shipment=nil)
    if shipment
      @shipment = shipment
      @address = shipment.order.ship_address
    else
      create_sample_data
    end
    {
      'shipment' =>
      {
        'number' => @shipment.number,
        'state' => @shipment.state,
        'stock_location_name' => @shipment.stock_location ? @shipment.try(:stock_location).try(:name) : "",
        'tracking_number' => @shipment.try(:tracking),
        'tracking_link' => @shipment.try(:tracking_url),
        'cost' => display_sweet_price(@shipment.cost, @shipment.order.vendor.currency).to_s,
        'shipped_at' => display_vendor_date_format(@shipment.shipped_at, @shipment.order.vendor.date_format),
        'ship_address' =>
        {
          'firstname' => @address.try(:firstname),
          'lastname' => @address.try(:lastname),
          'phone' => @address.try(:phone),
          'company' => @address.try(:company),
          'address1' => @address.try(:address1),
          'address2' => @address.try(:address2),
          'city' => @address.try(:city),
          'state_name' => @address.try(:state).try(:name),
          'zipcode' => @address.try(:zipcode),
          'country' => @address.try(:country).try(:name)
        }
      }
    }
  end

  def set_invoice_liquid_vars(invoice=nil)

    invoice_link = ""
    if invoice
      @invoice = invoice
      unless @invoice.id.blank?
        invoice_link = @invoice.vendor.use_separate_invoices ? invoice_url(@invoice, host: @invoice.vendor.domain, protocol: 'https') : edit_order_url(@invoice.orders.first, host: @invoice.vendor.domain, protocol: 'https')
      end
    else
      create_sample_data
    end
    {
    'invoice' =>
      {
        'number' => @invoice.number,
        'invoice_date' => display_vendor_date_format(@invoice.invoice_date, @invoice.vendor.date_format),
        'due_date' => display_vendor_date_format(@invoice.due_date, @invoice.vendor.date_format),
        'total' => display_sweet_price(@invoice.outstanding_balance, @invoice.vendor.currency).to_s,
        'item_count' => @invoice.item_count,
        'url' => invoice_link,
        'customer' =>
        {
          'name' => @invoice.try(:account).try(:name),
          'display_name' => @invoice.try(:account).try(:default_display_name),
          'fully_qualified_name' => @invoice.try(:account).try(:fully_qualified_name),
          'email' => @invoice.try(:account).try(:email)
        },
      },
    }
  end

  def set_contact_liquid_vars(company, contact=nil)
    unless contact
      contact = Spree::Contact.new(
        first_name: 'John',
        last_name: 'Smith',
        full_name: 'John Smith',
        email: 'john@smith.com'
      )
    end
    # let's identify the account this contact is assigned to and
    # give vendor user account attributes to use for the liquid email too, if needed
    unless contact.accounts.empty?
      contact.accounts.each do |account|
        if contact.accounts.first.vendor_id == company.id
          @account = account
        end
      end
    end
    {
      'my_company' =>
      {
        'name' => company ? company.name : "Test Company",
        'email' => company ? company.name : "company_email@website.com"
      },
      'contact' =>
      {
        'first_name' => contact.try(:first_name),
        'last_name' => contact.try(:last_name),
        'full_name' => contact.try(:full_name),
        'company' => contact.try(:company_name),
        'email' => contact.try(:email),
        'phone' => contact.try(:phone),
        'position' => contact.try(:position),
        'sign_up_url' => new_sign_up_url(id: contact.id, vendor: contact.company.try(:slug), host: company.domain, protocol: 'https')
      },
      'customer' =>
      {
        'name' => @account.try(:name),
        'display_name' => @account.try(:default_display_name),
        'fully_qualified_name' => @account.try(:fully_qualified_name),
        'email' => @account.try(:email),
      }
    }
  end

  private

  def create_sample_data
    @product = current_vendor.products.new(
      product_type: "non_inventory_item",
      name: "Sample line item",
      price: 25.99,
      available_on: Date.current-1.day,
      description: "Sample line description",
      pack_size: "Case"
    )
    @product.master.sku = 'SKU-123'
    @product.master.fully_qualified_name = "Sample line item"
    @product.master.price = 25.99
    @account = current_vendor.customer_accounts.new(
      name: 'Sample Customer',
      default_display_name: 'Sample Customer',
      fully_qualified_name: 'Sample Parent:Sample Customer',
      email: 'sample@sample.com'
    )
    @invoice = current_vendor.sales_invoices.new(
      number: 'R00034821',
      state: 'invoice',
      invoice_date: Date.current,
      end_date: Date.current,
      due_date: Date.current + 30.days,
      payment_state: 'balance_due',
      currency: current_vendor.currency,
      item_total: 129.95,
      shipment_total: 100.00,
      total: 229.95,
      account: @account,
    )
    @address = Spree::Address.new(
      firstname: "John",
      lastname: "Smith",
      phone: "999-999-9999",
      company: "Big Wholesale Limited",
      address1: "123 Main St.",
      address2: "Suite A",
      city: "New York",
      state_id: Spree::State.where(name:"New York").first,
      state_name: "NY",
      zipcode: "10000",
      country_id: Spree::Country.find_by_name("United States").id,
      addr_type: "shipping"
    )
    @shipment = current_vendor.sales_shipments.new(
      number: 'S12345',
      state: 'pending',
      stock_location_id: current_vendor.stock_locations.first,
      address_id: @address,
      tracking: 'Z9999999999',
      cost: 100.00,
      adjustment_total: 0,
      additional_tax_total: 0,
      promo_total: 0,
      included_tax_total: 0,
      pre_tax_amount: 100.00
    )
    @order = current_vendor.sales_orders.new(
      state: "invoice",
      delivery_date: Date.current,
      account: @account,
      item_total: 129.95,
      total: 229.95,
      shipment_total: 100,
      ship_address: @address,
      bill_address: @address,
      number: "R#{current_vendor.id}-R123"
    )
    @order.line_items.new(
      item_name: "Sample line item",
      variant: @product.master,
      quantity: 5,
      ordered_qty: 5,
      shipped_qty: 5,
      price: @product.master.price
    )

    @invoice.orders << @order
    @order.shipments << @shipment
  end


end
