module Spree::QboIntegration::Action::PaymentMethod

  def qbo_synchronize_payment_method(payment_method_id, payment_method_class)
    payment_method = Spree::PaymentMethod.find(payment_method_id)
    payment_method_hash = payment_method.to_integration(
        self.integration_item.integrationable_options_for(payment_method)
      )
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::PaymentMethod',
      integration_syncable_id: payment_method_id
    )

    qbo_update_or_create_payment_method(match, payment_method_hash)

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_update_or_create_payment_method(match, payment_method_hash)
    service = self.integration_item.qbo_service('PaymentMethod')

    if match.sync_id #match is found
      qbo_payment_method = service.fetch_by_id(match.sync_id)
      #perform update
      if self.integration_item.qbo_overwrite_conflicts_in == 'quickbooks'
        qbo_updated_payment_method = qbo_payment_method_to_qbo(qbo_payment_method, payment_method_hash)
        service.update(qbo_updated_payment_method)
        { status: 10, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => Match updated in QBO." }
      elsif self.integration_item.qbo_overwrite_conflicts_in == 'sweet'
        { status: 3, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => Not currently supported"}
      else
        { status: 10, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => No conflict resolution." }
      end
    else
      # try to match by name
      qbo_payment_method = service.query("select * from PaymentMethod where Name='#{payment_method_hash[:name]}'").first

      if qbo_payment_method
        # we have a match, save ID
        match.sync_id = qbo_payment_method.id
        match.sync_type = qbo_payment_method.class.to_s
        match.save
        #perform update
        if self.integration_item.qbo_overwrite_conflicts_in == 'quickbooks'
          qbo_updated_payment_method = qbo_payment_method_to_qbo(qbo_payment_method, payment_method_hash)
          service.update(qbo_updated_payment_method)
          { status: 10, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => Match updated in QBO." }
        elsif self.integration_item.qbo_overwrite_conflicts_in == 'sweet'
          { status: 3, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => Not currently supported"}
        else
          { status: 10, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => No conflict resolution." }
        end
      elsif self.integration_item.qbo_create_related_objects
        # try to create
        qbo_new_payment_method = qbo_payment_method_to_qbo(Quickbooks::Model::PaymentMethod.new, payment_method_hash)
        response = service.create(qbo_new_payment_method)
        match.sync_id = response.id
        match.sync_type = response.class.to_s
        match.save
        { status: 10, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => Pushed." }
      else
        { status: -1, log: "#{payment_method_hash.fetch(:name_for_integration)} payment_method => Unable to find Match for #{name}" }
      end
    end
  end

  def qbo_payment_method_to_qbo(qbo_payment_method, payment_method_hash)
    qbo_payment_method.name = payment_method_hash.fetch(:name)
    qbo_payment_method.active = payment_method_hash.fetch(:active)
    qbo_payment_method.type = qbo_payment_method_type_to_qbo(payment_method_hash.fetch(:credit_card))

    qbo_payment_method
  end

  def qbo_payment_method_type_to_qbo(is_credit_card)
    is_credit_card ? 'CREDIT_CARD' : 'NON_CREDIT_CARD'
  end

end
