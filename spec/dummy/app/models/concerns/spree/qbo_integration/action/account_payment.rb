module Spree::QboIntegration::Action::AccountPayment

  def qbo_synchronize_account_payment(account_payment_id, account_payment_class)
    account_payment = Spree::AccountPayment.find(account_payment_id)
    account_payment_hash = account_payment.to_integration(
        self.integration_item.integrationable_options_for(account_payment)
      )
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::AccountPayment',
      integration_syncable_id: account_payment_id
    )

    case account_payment_hash.fetch(:state)
    when 'completed'
      if account_payment_hash.fetch(:amount, 0).zero?
        qbo_void_account_payment(match, account_payment_hash)
      else
        qbo_update_or_create_account_payment(match, account_payment_hash)
      end
    when 'void'
      qbo_void_account_payment(match, account_payment_hash)
    else
      { status: -1, log: "Payment state '#{account_payment_hash.fetch(:state)}' not supported for sync" }
    end

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_void_account_payment(match, account_payment_hash)
    service = self.integration_item.qbo_service('Payment')
    if match.sync_id
      qbo_account_payment = service.fetch_by_id(match.sync_id)
    else
      qbo_account_payment = service.query("select * from Payment where PaymentRefNum='#{account_payment_hash[:ref_number]}'").first
    end

    if qbo_account_payment
      service.void(qbo_account_payment)
      { status: 10, log: "#{account_payment_hash.fetch(:name_for_integration)} payment => Voided" }
    else
      { status: 10, log: "Could not find payment(#{account_payment_hash[:ref_number]}) in Quickbooks. Void is not required." }
    end
  end

  def qbo_update_or_create_account_payment(match, account_payment_hash)
    service = self.integration_item.qbo_service('Payment')

    if match.sync_id #match is found
      qbo_account_payment = service.fetch_by_id(match.sync_id)
      #perform update
      qbo_updated_account_payment = qbo_account_payment_to_qbo(qbo_account_payment, account_payment_hash)
      service.update(qbo_updated_account_payment)
      { status: 10, log: "#{account_payment_hash.fetch(:name_for_integration)} account_payment => Match updated in QBO." }
    else
      # try to match by name
      qbo_account_payment = service.query("select * from Payment where PaymentRefNum='#{account_payment_hash[:ref_number]}'").first

      #txn_ids may not be uniq, so we can't assume it is the same payment
      if qbo_account_payment && account_payment_hash[:txn_id].blank?
        # we have a match, save ID
        match.sync_id = qbo_account_payment.id
        match.sync_type = qbo_account_payment.class.to_s
        match.save
        #perform update
        qbo_updated_account_payment = qbo_account_payment_to_qbo(qbo_account_payment, account_payment_hash)
        service.update(qbo_updated_account_payment)
        { status: 10, log: "#{account_payment_hash.fetch(:name_for_integration)} account_payment => Match updated in QBO." }
      else
        # try to create
        qbo_new_account_payment = qbo_account_payment_to_qbo(Quickbooks::Model::Payment.new, account_payment_hash)
        response = service.create(qbo_new_account_payment)
        match.sync_id = response.id
        match.sync_type = response.class.to_s
        match.save
        { status: 10, log: "#{account_payment_hash.fetch(:name_for_integration)} account_payment => Pushed." }
      end
    end
  end

  def qbo_account_payment_to_qbo(qbo_account_payment, account_payment_hash)

    account_payment_hash.fetch(:order_ids, []).each do |order_id|
      order_match = self.integration_item.integration_sync_matches.where(
        integration_syncable_type: 'Spree::Order',
        integration_syncable_id: order_id.to_i,
        sync_type: "Quickbooks::Model::#{self.integration_item.qbo_send_order_as}"
      ).first
      if order_match.try(:sync_id).nil?
        order = self.company.sales_orders.friendly.find(order_id)
        if States[order.state] < States['cart']
          raise "Cannot sync order #{order.display_number} with state '#{order.state}' for a payment"
        elsif States[order.state] < States['approved']
          raise "Order #{order.display_number} will not be synced to Quickbooks until it is approved. This payment sync will be automatically restarted when the order is approved."
        end

        order_status = qbo_synchronize_order(order_id, 'Spree::Order')
        order_match = self.integration_item.integration_sync_matches.where(
          integration_syncable_type: 'Spree::Order',
          integration_syncable_id: order_id.to_i,
          sync_type: "Quickbooks::Model::#{self.integration_item.qbo_send_order_as}"
        ).first
        unless order_match.try(:sync_id).present?
          error_message = "Unable to find/create an associated order in Quickbooks."
          order_status.fetch(:status, 0).to_i < 0 && order_status.fetch(:log, '').present?
          error_message += "\n#{order_status.fetch(:log)}"
          raise Exception.new(error_message)
        end
      end
    end

    account_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::Account',
      integration_syncable_id: account_payment_hash.fetch(:account_id, nil)
    )
    qbo_synchronize_payment_method(account_payment_hash.fetch(:payment_method_id, nil), 'Spree::PaymentMethod')
    pm_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::PaymentMethod',
      integration_syncable_id: account_payment_hash.fetch(:payment_method_id, nil)
    )
    qbo_account_payment.customer_ref = Quickbooks::Model::BaseReference.new(account_match.try(:sync_id))
    qbo_account_payment.txn_date = account_payment_hash.fetch(:payment_date)
    qbo_account_payment.total = account_payment_hash.fetch(:amount, 0)
    qbo_account_payment.payment_ref_number = account_payment_hash.fetch(:ref_number)
    qbo_account_payment.payment_method_ref = Quickbooks::Model::BaseReference.new(pm_match.try(:sync_id))

    if integration_item.qbo_multi_currency
      qbo_account_payment.currency_ref = Quickbooks::Model::BaseReference.new(account_payment_hash.fetch(:currency))
      qbo_account_payment.exchange_rate = qbo_exchange_rate(account_payment_hash.fetch(:currency)) # Need to supply an exchange rate for multi-currency
    end

    set_deposit_to_account_ref(qbo_account_payment)

    qbo_account_payment.line_items = []

    # can support multiple lines for account_payment, not sure what case this would apply to.


    # create loop if applying to more than one order/invoice - not yet supported in SWEET 7/26/2017
    account_payment_hash.fetch(:inner_payments).each do |inner_payment|
      order_match = self.integration_item.integration_sync_matches.where(
        integration_syncable_id: inner_payment.fetch(:order_id),
        integration_syncable_type: 'Spree::Order',
        sync_type: "Quickbooks::Model::#{self.integration_item.qbo_send_order_as}"
      ).first
      next if order_match.nil?
      line = Quickbooks::Model::Line.new
      line.payment! #sets detail type and intialize line detail
      line.amount = inner_payment.fetch(:amount, 0)
      line.linked_transactions = []

      txn = Quickbooks::Model::LinkedTransaction.new
      txn.txn_id = order_match.sync_id
      txn.txn_type = order_match.sync_type.to_s.demodulize
      line.linked_transactions << txn

      # TODO set account_payment_line_details if needed
      # line.account_payment_line_details =

      qbo_account_payment.line_items << line
    end

    if account_payment_hash.fetch(:amount_to_credit, 0) > 0
      line = Quickbooks::Model::Line.new
      line.payment! #sets detail type and intialize line detail
      line.amount = account_payment_hash.fetch(:amount_to_credit, 0)
    end



    qbo_account_payment
  end

  def set_deposit_to_account_ref(qbo_account_payment)
    if self.integration_item.qbo_deposit_to_account.present?
      service = self.integration_item.qbo_service('Account')
      qbo_account = service.query("select * from Account where FullyQualifiedName='#{self.integration_item.qbo_deposit_to_account}'").first
      if qbo_account
        qbo_account_payment.deposit_to_account_ref = Quickbooks::Model::BaseReference.new(qbo_account.try(:id))
      else
        raise Exception.new("Unable to find Account in Quickbooks with name: #{self.integration_item.qbo_deposit_to_account}")
      end
    end
  end

end
