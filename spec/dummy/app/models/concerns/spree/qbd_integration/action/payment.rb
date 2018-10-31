module Spree::QbdIntegration::Action::Payment

  def qbd_payment_step(payment_id, parent_step_id = nil)
    payment = Spree::Payment.find(payment_id)
    payment_hash = payment.to_integration(
        self.integration_item.integrationable_options_for(payment)
      )

    payment_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: payment_id,
      integration_syncable_type: 'Spree::Payment',
      sync_type: 'ReceivePayment'
    )
    unless self.integration_steps.where(integrationable_type: 'Spree::Payment', integration_syncable_id: payment_id).first || self.current_step.present? || parent_step_id
      next_step = qbd_payment_query_step_hash(payment_id).merge({next_step: :continue})
      next_step.merge!({qbxml_query_by: 'TxnID', sync_id: payment_match.sync_id}) if payment_match.sync_id.present?
      next_step = qbd_create_step(next_step)
      next_step.update_columns(sync_id: payment_match.sync_id)
      return next_step.details
    end

    # only the payment number is uniq, we do not want to query on a Check# that
    # could easily be duplicated, and customer is not filterable here
    if payment_match.sync_id.nil? && (payment_hash.fetch(:payment_method, {}).fetch(:credit_card) || payment_hash.fetch(:txn_id, '').blank?)
      next_step = qbd_payment_query_step_hash(payment_id)
    elsif payment_match.sync_id.blank?
      next_step = { step_type: :create, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
    else
      if ['void'].include?(payment_hash.fetch(:state))
        next_step = { step_type: :delete, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      elsif payment_match.sync_id.present?# && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = { step_type: :push, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      # NOTE: Only support pushing payments to QBD
      # elsif payment_match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
      #   next_step = { step_type: :pull, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      else
        next_step = { step_type: :query, next_step: :skip, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      end
    end

    payment_step = qbd_create_step(next_step, parent_step_id)

    # Sync account
    account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: payment_hash.fetch(:account_id), integration_syncable_type: 'Spree::Account')
    if account_match.synced_at.nil? || account_match.synced_at < Time.current# - 2.minute
      qbd_create_step(
        self.qbd_account_step(account_match.integration_syncable_id, payment_step.id),
        payment_step.id
      )
    end

    # Sync Order
    order_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: payment_hash.fetch(:order_id),
      integration_syncable_type: 'Spree::Order',
      sync_type: self.integration_item.qbd_order_xml_class
    )
    if order_match.synced_at.nil?
      qbd_create_step(
        self.qbd_order_step(order_match.integration_syncable_id, payment_step.id),
        payment_step.id
      )
    end

    # TODO find or create payment method (ie. Visa, Master Card, AmEx, not StripeGateway)
    # payment_method_match = self.integration_item.integration_sync_matches.find_or_create_by(
    #   integration_syncable_id: payment_hash.fetch(:payment_method_id),
    #   integration_syncable_type: 'Spree::PaymentMethod',
    #   sync_type: 'PaymentMethod'
    # )
    # if payment_method_match.synced_at.nil? || payment_method_match.synced_at < Time.current# - 2.minute
    #   # need to send payment instead of payment method to have access to more details
    #   # such as credit card type
    #   qbd_create_step(
    #     self.qbd_payment_method_step(payment_id),
    #     payment_step.try(:id)
    #   )
    # end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_payment_to_receive_payment_xml(xml, payment_hash, payment_match = nil)
    account = Spree::Account.find(payment_hash.fetch(:account_id))
    account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    if payment_match.try(:sync_id)
      xml.TxnID       payment_match.try(:sync_id)
      xml.EditSequence payment_match.try(:sync_alt_id)
    end

    xml.CustomerRef do
      xml.ListID       account_match.try(:sync_id)
    end

    if self.integration_item.qbd_accounts_receivable_account.present?
      xml.ARAccountRef do
        xml.FullName    self.integration_item.qbd_accounts_receivable_account
      end
    end

    xml.TxnDate         payment_hash.fetch(:created_at).to_date.to_s
    xml.RefNumber       qbd_payment_ref_number(payment_hash)
    xml.TotalAmount     qbd_amt_type(payment_hash.fetch(:amount))

    payment_method_name = qbd_payment_method_name(payment_hash.fetch(:source_type), payment_hash.fetch(:source), payment_hash.fetch(:payment_method))
    if payment_method_name.present?
      xml.PaymentMethodRef do
        xml.FullName  payment_method_name
      end
    end
    unless payment_hash.fetch(:payment_method, {}).fetch(:credit_card)
      xml.Memo payment_hash.fetch(:memo)
    end

    if self.integration_item.qbd_deposit_to_account.present?
      xml.DepositToAccountRef do
        xml.FullName    self.integration_item.qbd_deposit_to_account
      end
    end
    order_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: payment_hash.fetch(:order_id),
      integration_syncable_type: 'Spree::Order',
      sync_type: self.integration_item.qbd_order_xml_class
    )

    if payment_match.try(:sync_id)
      xml.AppliedToTxnMod do
        xml.TxnID          order_match.try(:sync_id)
        xml.PaymentAmount   qbd_amt_type(payment_hash.fetch(:amount))
      end
    else
      xml.AppliedToTxnAdd do
        xml.TxnID          order_match.try(:sync_id)
        xml.PaymentAmount   qbd_amt_type(payment_hash.fetch(:amount))
      end
    end
  end

  def qbd_payment_to_delete_receive_payment_xml(xml, payment_hash, match = nil)
    xml.TxnDelType   'ReceivePayment'
    xml.TxnID         match.try(:sync_id)
  end

  def qbd_payment_method_name(type, source, payment_method)
    if payment_method.fetch(:credit_card)
      card_type = source.try(:cc_type)
      case card_type
      when 'master'
        'Master Card'
      when 'visa'
        'Visa'
      when 'discover'
        'Discover'
      when 'american_express'
        'American Express'
      else
        'Other Credit Card'
      end
    else
      case payment_method.fetch(:type).to_s.demodulize.downcase
      when 'cash'
        'Cash'
      when 'check'
        'Check'
      else
        'Other'
      end
    end
  end

  def qbd_payment_ref_number(payment_hash)
    pm = payment_hash.fetch(:payment_method, {})
    if pm.fetch(:credit_card)
      payment_hash.fetch(:number, '')
    else
      payment_hash.fetch(:ref_number, '')
    end
  end

  def qbd_receive_payment_xml_to_payment(response, payment_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ReceivePaymentRs/ReceivePaymentRet'
    {
      # name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    }.delete_if { |k, v| v.blank? }
  end

  def qbd_all_associated_matched_receive_payment?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ReceivePaymentRs/ReceivePaymentRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ReceivePaymentRet", {})

    qbd_receive_payment_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_receive_payment_find_or_assign_associated_opts(qbd_hash, payment = nil)

  end

  def qbd_payment_query_step_hash(payment_id)
    { step_type: :query, next_step: :skip, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
  end
  def qbd_payment_create_step_hash(payment_id)
    { step_type: :create, run_callbacks: true, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
  end
  def qbd_payment_push_step_hash(payment_id)
    { step_type: :push, run_callbacks: true, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
  end
  def qbd_payment_pull_step_hash(payment_id)
    { step_type: :pull, run_callbacks: true, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
  end
  def qbd_payment_delete_step_hash(payment_id)
    { step_type: :delete, run_callbacks: true, object_id: payment_id, object_class: 'Spree::Payment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
  end

  def qbd_create_payment_callback_steps(payment_id)
    return unless self.integration_item.qbd_use_external_balance
    payment_hash = Spree::Payment.find(payment_id).to_integration
    # qbd_create_step(
    #   self.qbd_account_step(payment_hash.fetch(:account_id)).merge(force_create: true)
    # )
    # TODO fix to use integration steps rather than create new job

    self.company
        .customer_accounts
        .find_by_id(payment_hash.fetch(:account_id))
        .try(:notify_integration)
  end
end
