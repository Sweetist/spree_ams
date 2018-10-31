module Spree::QboIntegration::Action::Payment

  def qbo_synchronize_payment(payment_id, payment_class)
    payment = Spree::Payment.find(payment_id)
    payment_hash = payment.to_integration(
        self.integration_item.integrationable_options_for(payment)
      )
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::Payment',
      integration_syncable_id: payment_id
    )

    case payment_hash.fetch(:state)
    when 'completed'
      if payment_hash.fetch(:amount, 0).zero?
        qbo_void_payment(match, payment_hash)
      else
        qbo_update_or_create_payment(match, payment_hash)
      end
    when 'void'
      qbo_void_payment(match, payment_hash)
    else
      { status: -1, log: "Payment state '#{payment_hash.fetch(:state)}' not supported for sync" }
    end

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_void_payment(match, payment_hash)
    service = self.integration_item.qbo_service('Payment')
    if match.sync_id
      qbo_payment = service.fetch_by_id(match.sync_id)
    else
      qbo_payment = service.query("select * from Payment where PaymentRefNum='#{payment_hash[:number]}'").first
    end

    if qbo_payment
      service.void(qbo_payment)
      { status: 10, log: "#{payment_hash.fetch(:name_for_integration)} payment => Voided" }
    else
      { status: 10, log: "Could not find payment(#{payment_hash[:number]}) in Quickbooks. Void is not required." }
    end
  end

  def qbo_update_or_create_payment(match, payment_hash)
    service = self.integration_item.qbo_service('Payment')

    if match.sync_id #match is found
      qbo_payment = service.fetch_by_id(match.sync_id)
      #perform update
      qbo_updated_payment = qbo_payment_to_qbo(qbo_payment, payment_hash)
      service.update(qbo_updated_payment)
      { status: 10, log: "#{payment_hash.fetch(:name_for_integration)} payment => Match updated in QBO." }
    else
      # try to match by name
      qbo_payment = service.query("select * from Payment where PaymentRefNum='#{payment_hash[:number]}'").first

      if qbo_payment
        # we have a match, save ID
        match.sync_id = qbo_payment.id
        match.sync_type = qbo_payment.class.to_s
        match.save
        #perform update
        qbo_updated_payment = qbo_payment_to_qbo(qbo_payment, payment_hash)
        service.update(qbo_updated_payment)
        { status: 10, log: "#{payment_hash.fetch(:name_for_integration)} payment => Match updated in QBO." }
      elsif self.integration_item.qbo_create_related_objects
        # try to create
        qbo_new_payment = qbo_payment_to_qbo(Quickbooks::Model::Payment.new, payment_hash)
        response = service.create(qbo_new_payment)
        match.sync_id = response.id
        match.sync_type = response.class.to_s
        match.save
        { status: 10, log: "#{payment_hash.fetch(:name_for_integration)} payment => Pushed." }
      else
        { status: -1, log: "#{payment_hash.fetch(:name_for_integration)} payment => Unable to find Match for #{name}" }
      end
    end
  end

  def qbo_payment_to_qbo(qbo_payment, payment_hash)
    order_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::Order',
      integration_syncable_id: payment_hash.fetch(:order_id, nil),
      sync_type: "Quickbooks::Model::#{self.integration_item.qbo_send_order_as}"
    ).first

    if order_match.try(:sync_id).nil?
      order_status = qbo_synchronize_order(payment_hash.fetch(:order_id, nil), 'Spree::Order')
      order_match = self.integration_item.integration_sync_matches.where(
        integration_syncable_type: 'Spree::Order',
        integration_syncable_id: payment_hash.fetch(:order_id, nil),
        sync_type: "Quickbooks::Model::#{self.integration_item.qbo_send_order_as}"
      ).first
      unless order_match.try(:sync_id).present?
        raise Exception.new("Unable to find/create an associated order in Quickbooks")
      end
    end

    if order_match.sync_id.present?
      account_match = self.integration_item.integration_sync_matches.find_or_create_by(
        integration_syncable_type: 'Spree::Account',
        integration_syncable_id: payment_hash.fetch(:account_id, nil)
      )
      qbo_synchronize_payment_method(payment_hash.fetch(:payment_method_id, nil), 'Spree::PaymentMethod')
      pm_match = self.integration_item.integration_sync_matches.find_or_create_by(
        integration_syncable_type: 'Spree::PaymentMethod',
        integration_syncable_id: payment_hash.fetch(:payment_method_id, nil)
      )
      qbo_payment.customer_ref = Quickbooks::Model::BaseReference.new(account_match.try(:sync_id))
      qbo_payment.txn_date = payment_hash.fetch(:created_at)
      qbo_payment.total = payment_hash.fetch(:amount, 0)
      qbo_payment.payment_ref_number = payment_hash.fetch(:number)
      qbo_payment.payment_method_ref = Quickbooks::Model::BaseReference.new(pm_match.try(:sync_id))

      if integration_item.qbo_multi_currency
        qbo_payment.currency_ref = Quickbooks::Model::BaseReference.new(payment_hash.fetch(:currency))
        qbo_payment.exchange_rate = qbo_exchange_rate(payment_hash.fetch(:currency)) # Need to supply an exchange rate for multi-currency
      end

      set_deposit_to_account_ref(qbo_payment)

      qbo_payment.line_items = []

      # can support multiple lines for payment, not sure what case this would apply to.
      line = Quickbooks::Model::Line.new
      line.payment! #sets detail type and intialize line detail
      line.amount = payment_hash.fetch(:amount, 0)
      line.linked_transactions = []

      # create loop if applying to more than one order/invoice - not yet supported in SWEET 7/26/2017
      txn = Quickbooks::Model::LinkedTransaction.new
      txn.txn_id = order_match.sync_id
      txn.txn_type = order_match.sync_type.to_s.demodulize

      line.linked_transactions << txn

      # TODO set payment_line_details if needed
      # line.payment_line_details =

      qbo_payment.line_items << line
    end

    qbo_payment
  end

  def set_deposit_to_account_ref(qbo_payment)
    if self.integration_item.qbo_deposit_to_account.present?
      service = self.integration_item.qbo_service('Account')
      qbo_account = service.query("select * from Account where FullyQualifiedName='#{self.integration_item.qbo_deposit_to_account}'").first
      if qbo_account
        qbo_payment.deposit_to_account_ref = Quickbooks::Model::BaseReference.new(qbo_account.try(:id))
      else
        raise Exception.new("Unable to find Account in Quickbooks with name: #{self.integration_item.qbo_deposit_to_account}")
      end
    end
  end

end
