module Spree::QboIntegration::Action::Vendor
  def qbo_synchronize_vendor(vendor_account_id, vendor_class)
    account = self.company.vendor_accounts.find(vendor_account_id)
    vendor_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    qbo_vendor_company = {}

    # if qbo_vendor_company.fetch(:status, 10) == 10
      vendor_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: vendor_account_id, integration_syncable_type: vendor_class)
      service = self.integration_item.qbo_service('Vendor')
      if vendor_match.sync_id
        # we have vendor_match, push data
        qbo_vendor = service.fetch_by_id(vendor_match.sync_id)
        qbo_update_vendor(vendor_hash, qbo_vendor, service)
      else
        # try to match by name
        qbo_vendor = service.find_by(:display_name, self.qbo_safe_string(vendor_hash.fetch(:fully_qualified_name))).first

        if qbo_vendor
          # we have a vendor_match, save ID
          vendor_match.sync_id = qbo_vendor.id
          vendor_match.sync_type = qbo_vendor.class.to_s
          vendor_match.save
          qbo_update_vendor(vendor_hash, qbo_vendor, service)
        else
          # no vendor_match
          if self.integration_item.qbo_create_related_objects
            # no vendor_match, create new!
            qbo_new_vendor = qbo_vendor_to_qbo(Quickbooks::Model::Vendor.new, vendor_hash.fetch(:account, {}))
            response = service.create(qbo_new_vendor)
            vendor_match.sync_id = response.id
            vendor_match.sync_type = response.class.to_s
            vendor_match.save
            { status: 10, log: "#{vendor_hash.fetch(:account, {}).fetch(:name_for_integration)} => Pushed." }
          else
            # no vendor_match, no create
            { status: -1, log: "#{vendor_hash.fetch(:account, {}).fetch(:name_for_integration)} => Unable to find vendor_match" }
          end
        end
      end
    # else
    #   qbo_vendor_company
    # end
    rescue Exception => e
      { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_update_vendor(vendor_hash, qbo_vendor, service)
    if self.integration_item.qbo_vendor_overwrite_conflicts_in == 'quickbooks'
      qbo_updated_vendor = qbo_vendor_to_qbo(qbo_vendor, vendor_hash.fetch(:account,{}))
      service.update(qbo_updated_vendor)
      { status: 10, log: "#{vendor_hash.fetch(:account, {}).fetch(:name_for_integration)} => vendor match updated in QBO." }
    elsif self.integration_item.qbo_vendor_overwrite_conflicts_in == 'sweet'
      vendor_hash.fetch(:account, {}).fetch(:self).from_integration({
        account: self.qbo_vendor_to_account(qbo_vendor),
        bill_address: self.qbo_vendor_to_bill_address(qbo_vendor, vendor_hash)
      })
      { status: 10, log: "#{vendor_hash.fetch(:account, {}).fetch(:name_for_integration)} => vendor match updated in Sweet." }
    else
      { status: 10, log: "#{vendor_hash.fetch(:account, {}).fetch(:name_for_integration)} => Vendor matched without update." }
    end
  end

  def qbo_vendor_to_qbo(qbo_vendor, vendor_hash)
    vendor = vendor_hash
    parent_vendor_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: vendor_hash.fetch(:parent_id), integration_syncable_type: 'Spree::Account')

    qbo_vendor.given_name = vendor.fetch(:firstname, '')
    qbo_vendor.family_name = vendor.fetch(:lastname, '')
    qbo_vendor.company_name = vendor.fetch(:name, '').to_s.split(':').first.to_s
    qbo_vendor.display_name = vendor.fetch(:name, '')

    qbo_vendor.active = vendor.fetch(:active)
    bill_address = vendor_hash.fetch(:billing_address, nil)
    billing_address_hash = bill_address.try(
        :to_integration,
        self.integration_item.integrationable_options_for(bill_address)
      ) || {}

    qbo_vendor.primary_phone = self.qbo_phone_to_qbo(qbo_vendor.primary_phone || Quickbooks::Model::TelephoneNumber.new, billing_address_hash.fetch(:phone, nil))
    qbo_vendor.primary_email_address = self.qbo_email_to_qbo(qbo_vendor.primary_email_address || Quickbooks::Model::EmailAddress.new, vendor_hash.fetch(:email, nil))

    qbo_vendor.billing_address = self.qbo_address_to_qbo(qbo_vendor.billing_address || Quickbooks::Model::PhysicalAddress.new, billing_address_hash, false)

    qbo_vendor
  end

  def qbo_vendor_to_account(qbo_vendor)
    {
      name: qbo_vendor.display_name,
      email: qbo_vendor.primary_email_address.try(:address)
    }.compact.merge({
      inactive_date: qbo_vendor.active? ? nil : Date.current
    })
  end
end
