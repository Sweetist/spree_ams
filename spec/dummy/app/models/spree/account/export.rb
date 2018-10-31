module Spree::Account::Export
  def to_csv(options = {})
    CSV.generate(options) do |csv|
      addresses_count = all.joins(:shipping_addresses)
                           .select('spree_accounts.customer_id, COUNT(spree_addresses.id) as addr_count')
                           .group('spree_accounts.id')
                           .order('addr_count DESC')
                           .first.try(:addr_count)

      @max_ship_addresses_count = if addresses_count.nil?
                                    1
                                  elsif addresses_count > 10
                                    10
                                  else
                                    addresses_count
                                  end
      csv << line_head
      all.includes(
        :note,
        :rep,
        :customer_type,
        :customer,
        :vendor,
        :default_stock_location,
        :default_shipping_method,
        :payment_terms,
        :shipping_group,
        primary_cust_contact: [:user],
        shipping_addresses: [:state, :country],
        billing_addresses: [:state, :country]).each do |account|
        @bill_address = account.bill_address
        account_active = account.active? ? 'Y' : ''
        account_taxable = account.taxable ? 'Y' : ''
        primary_contact = account.primary_cust_contact
        line_base = [
          account.fully_qualified_name,
          account.display_name,
          account.customer.try(:name),
          account.number,
          account_active,
          DateHelper.display_vendor_date_format(account.inactive_date, account.vendor.date_format),
          account.time_zone,
          DateHelper.display_vendor_date_format(account.last_invoice_date, account.vendor.date_format),
          account.email,
          account.shipment_email,
          account_taxable,
          account.customer_type.try(:name),
          account.payment_terms.try(:name),
          account.credit_limit,
          account.shipping_group.try(:name),
          account.default_shipping_method.try(:name),
          account.default_stock_location.try(:name),
          account.note.try(:body),
          account.rep.try(:name),
          primary_contact.try(:email),
          primary_contact.try(:first_name),
          primary_contact.try(:last_name),
          primary_contact.try(:phone)
        ]
        line_base += address_line('bill')
        @max_ship_addresses_count.times do |i|
          @ship_address = account.shipping_addresses[i]
          line_base += address_line('ship')
        end
        line_base += [
          DateHelper.display_vendor_date_time_format(account.created_at, account.vendor.date_format, account.time_zone),
          DateHelper.display_vendor_date_time_format(account.created_at, account.vendor.date_format, account.time_zone)
        ]
        csv << line_base
      end
    end
  end

  def line_head
    if @max_ship_addresses_count > 1
      multi_address_line_head
    else
      single_address_line_head
    end
  end

  def single_address_line_head
    [
      'Customer',
      'Display Name',
      'Company (Not currently editable through app)',
      'Account Number',
      'Active',
      'Inactive Date',
      'Time Zone',
      'Last Invoice Date',
      'Email',
      'Shipment Email',
      'Taxable',
      'Customer Type',
      'Payment Term',
      'Credit Limit',
      'Shipping Schedule',
      'Default Shipping Method',
      'Default Stock Location',
      'Customer Notes',
      'Sales Rep Name',
      'Contact Email',
      'Contact First Name',
      'Contact Last Name',
      'Contact Phone'
    ] + address_line_head('Bill') + address_line_head('Ship') + ['Created At', 'Updated At']
  end

  def multi_address_line_head
    line_head = [
      'Customer',
      'Display Name',
      'Company (Not currently editable through app)',
      'Account Number',
      'Active',
      'Inactive Date',
      'Time Zone',
      'Last Invoice Date',
      'Email',
      'Shipment Email',
      'Taxable',
      'Customer Type',
      'Payment Term',
      'Credit Limit',
      'Shipping Schedule',
      'Default Shipping Method',
      'Default Stock Location',
      'Customer Notes',
      'Sales Rep Name',
      'Contact Email',
      'Contact First Name',
      'Contact Last Name',
      'Contact Phone'
    ] + address_line_head('Bill')
    @max_ship_addresses_count.times do |i|
      address = [
        "Ship#{i + 1}: First Name",
        "Ship#{i + 1}: Last Name",
        "Ship#{i + 1}: Address 1",
        "Ship#{i + 1}: Address 2",
        "Ship#{i + 1}: Company",
        "Ship#{i + 1}: City",
        "Ship#{i + 1}: State",
        "Ship#{i + 1}: Zip",
        "Ship#{i + 1}: Country",
        "Ship#{i + 1}: Phone        "
      ]
      line_head += address
    end
    line_head += ['Created At', 'Updated At']
  end

  def address_line(address_type)
    [
      instance_variable_get("@#{address_type}_address").try(:firstname),
      instance_variable_get("@#{address_type}_address").try(:lastname),
      instance_variable_get("@#{address_type}_address").try(:address1),
      instance_variable_get("@#{address_type}_address").try(:address2),
      instance_variable_get("@#{address_type}_address").try(:company),
      instance_variable_get("@#{address_type}_address").try(:city),
      instance_variable_get("@#{address_type}_address").try(:state).try(:abbr),
      instance_variable_get("@#{address_type}_address").try(:zipcode),
      instance_variable_get("@#{address_type}_address").try(:country).try(:name),
      instance_variable_get("@#{address_type}_address").try(:phone)
    ]
  end

  def address_line_head(address_type)
    [
      "#{address_type} First Name",
      "#{address_type} Last Name",
      "#{address_type} Address 1",
      "#{address_type} Address 2",
      "#{address_type} Company",
      "#{address_type} City",
      "#{address_type} State",
      "#{address_type} Zip",
      "#{address_type} Country",
      "#{address_type} Phone        "
    ]
  end
end
