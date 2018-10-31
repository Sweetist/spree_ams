module Integrations
  module Customer
    def customer_data
      return @customer_data if @customer_data.present?
      customer_params = @data.slice(*Spree::Account.attribute_names)
      return nil if customer_params.blank?
      customer_params.delete('id')
      @customer_data = customer_params.with_indifferent_access
                                      .merge(additional_data_for_customer)
    end

    def spree_object
      return find_or_create_customer if customer_data.present?
      raise Error, I18n.t('integrations.no_customer_data')
    end

    def finded_customer
      customer = find_object_by(sync_id: sync_id,
                                sync_type: sync_type,
                                klass: 'Spree::Account')
      customer ||= vendor_object.customer_accounts.find_by(name: full_name)
      customer ||= vendor_object.customer_accounts
                                .where('email ilike ?', email)
                                .first
      return customer if customer.present?
    end

    def updated_customer
      update_assign_sync_id(finded_customer)
      finded_customer.update!(customer_data)
      add_addresses_to(finded_customer)
      save_result(finded_customer, 'updated')
      finded_customer
    end

    def find_or_create_customer
      return updated_customer if finded_customer.present?
      create_customer
    end

    def add_addresses_to(customer_account)
      if billing_address
        customer_account
          .bill_address = "#{self.class.parent}::Address"
            .constantize
            .new(billing_address
                 .merge(addr_type: 'billing')
                 .merge(parameters: parameters))
            .spree_object
      end
      if shipping_address
        customer_account
          .shipping_addresses = ["#{self.class.parent}::Address"
            .constantize
            .new(shipping_address
                 .merge(addr_type: 'shipping')
                 .merge(parameters: parameters))
            .spree_object]
        customer_account.default_ship_address_id = customer_account.shipping_addresses.first.id
      end
      customer_account.save if (billing_address || shipping_address)
    end

    def create_customer
      customer_account = vendor_object
                         .customer_accounts
                         .new(customer_data)
      customer_account.customer = customer_company
      customer_account.default_stock_location = stock_location_object
      customer_account.parent_id = parent_account_object.id if parent_account_object
      customer_account.save!
      add_addresses_to(customer_account)
      create_assign_sync_id(customer_account)
      save_result(finded_customer, 'created')
      customer_account.reload
    end

    def customer_company
      company = vendor_object.customers.find_by(name: full_name)
      return company if company.present?

      company = vendor_object.customers.new(name: full_name,
                                            time_zone: vendor_object.time_zone)
      company.save
      company
    end

    def full_name
      name = "#{firstname} #{lastname}".strip
      return name if name.present?

      email
    end

    def additional_data_for_customer
      {
        taxable: !@data[:tax_exempt] || false,
        name: full_name,
        channel: sync_type
      }
    end
  end
end
