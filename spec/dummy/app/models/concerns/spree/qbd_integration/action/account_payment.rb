module Spree::QbdIntegration::Action::AccountPayment

  def qbd_account_payment_step(account_payment_id, parent_step_id = nil)
    account_payment = Spree::AccountPayment.find(account_payment_id)
    account_payment_hash = account_payment.to_integration(
        self.integration_item.integrationable_options_for(account_payment)
      )

    account_payment_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: account_payment_id,
      integration_syncable_type: 'Spree::AccountPayment',
      sync_type: 'ReceivePayment'
    )
    unless self.integration_steps.where(integrationable_type: 'Spree::AccountPayment', integration_syncable_id: account_payment_id).first || self.current_step.present? || parent_step_id
      next_step = qbd_account_payment_query_step_hash(account_payment_id).merge({next_step: :continue})
      next_step.merge!({qbxml_query_by: 'TxnID', sync_id: account_payment_match.sync_id}) if account_payment_match.sync_id.present?
      next_step = qbd_create_step(next_step)
      next_step.update_columns(sync_id: account_payment_match.sync_id)
      return next_step.details
    end

    # only the account_payment number is uniq, we do not want to query on a Check# that
    # could easily be duplicated, and customer is not filterable here
    if account_payment_match.sync_id.nil? && (account_payment_hash.fetch(:payment_method, {}).fetch(:credit_card) || account_payment_hash.fetch(:txn_id, '').blank?)
      next_step = qbd_account_payment_query_step_hash(account_payment_id)
    elsif account_payment_match.sync_id.blank?
      next_step = { step_type: :create, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
    else
      if ['void'].include?(account_payment_hash.fetch(:state))
        next_step = { step_type: :delete, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      elsif account_payment_match.sync_id.present?# && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = { step_type: :push, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      # NOTE: Only support pushing account_payments to QBD
      # elsif account_payment_match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
      #   next_step = { step_type: :pull, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      else
        next_step = { step_type: :query, next_step: :skip, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
      end
    end

    account_payment_step = qbd_create_step(next_step, parent_step_id)

    # Sync account
    account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_payment_hash.fetch(:account_id), integration_syncable_type: 'Spree::Account')
    if account_match.synced_at.nil? || account_match.synced_at < Time.current# - 2.minute
      qbd_create_step(
        self.qbd_account_step(account_match.integration_syncable_id, account_payment_step.id),
        account_payment_step.id
      )
    end

    # Sync Order
    account_payment.orders.each do |order|
      next unless self.integration_item.qbd_should_sync_order(order)
      order_match = self.integration_item.integration_sync_matches.find_or_create_by(
        integration_syncable_id: order.id,
        integration_syncable_type: 'Spree::Order',
        sync_type: self.integration_item.qbd_order_xml_class
      )

      if order_match.synced_at.nil?
        qbd_create_step(
          self.qbd_order_step(order_match.integration_syncable_id, account_payment_step.id),
          account_payment_step.id
        )
      end
    end

    # TODO find or create account_payment method (ie. Visa, Master Card, AmEx, not StripeGateway)
    # payment_method_match = self.integration_item.integration_sync_matches.find_or_create_by(
    #   integration_syncable_id: account_payment_hash.fetch(:payment_method_id),
    #   integration_syncable_type: 'Spree::AccountPaymentMethod',
    #   sync_type: 'PaymentMethod'
    # )
    # if payment_method_match.synced_at.nil? || payment_method_match.synced_at < Time.current# - 2.minute
    #   # need to send account_payment instead of account_payment method to have access to more details
    #   # such as credit card type
    #   qbd_create_step(
    #     self.qbd_payment_method_step(account_payment_id),
    #     account_payment_step.try(:id)
    #   )
    # end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_account_payment_to_receive_payment_xml(xml, account_payment_hash, account_payment_match = nil)
    account = Spree::Account.find(account_payment_hash.fetch(:account_id))
    account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.id, integration_syncable_type: 'Spree::Account')
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    if account_payment_match.try(:sync_id)
      xml.TxnID       account_payment_match.try(:sync_id)
      xml.EditSequence account_payment_match.try(:sync_alt_id)
    end

    xml.CustomerRef do
      xml.ListID       account_match.try(:sync_id)
    end

    if self.integration_item.qbd_accounts_receivable_account.present?
      xml.ARAccountRef do
        xml.FullName    self.integration_item.qbd_accounts_receivable_account
      end
    end

    xml.TxnDate         account_payment_hash.fetch(:payment_date).to_date.to_s
    xml.RefNumber       qbd_account_payment_ref_number(account_payment_hash)
    xml.TotalAmount     qbd_amt_type(account_payment_hash.fetch(:amount))

    payment_method_name = qbd_payment_method_name(account_payment_hash.fetch(:source_type), account_payment_hash.fetch(:source), account_payment_hash.fetch(:payment_method))
    if payment_method_name.present?
      xml.PaymentMethodRef do
        xml.FullName  payment_method_name
      end
    end
    unless account_payment_hash.fetch(:payment_method, {}).fetch(:credit_card)
      xml.Memo account_payment_hash.fetch(:memo)
    end

    if self.integration_item.qbd_deposit_to_account.present?
      xml.DepositToAccountRef do
        xml.FullName    self.integration_item.qbd_deposit_to_account
      end
    end
    if self.integration_item.qbd_send_order_as == 'sales_order'
      xml.IsAutoApply   self.integration_item.qbd_auto_apply_payment
    else
      account_payment_hash.fetch(:inner_payments).each do |inner_payment|
        order_match = self.integration_item.integration_sync_matches.where(
          integration_syncable_id: inner_payment.fetch(:order_id),
          integration_syncable_type: 'Spree::Order',
          sync_type: self.integration_item.qbd_order_xml_class
        ).first
        next if order_match.nil?
        if account_payment_match.try(:sync_id)
          xml.AppliedToTxnMod do
            xml.TxnID          order_match.try(:sync_id)
            xml.PaymentAmount   qbd_amt_type(inner_payment.fetch(:amount))
          end
        else
          xml.AppliedToTxnAdd do
            xml.TxnID          order_match.try(:sync_id)
            xml.PaymentAmount   qbd_amt_type(inner_payment.fetch(:amount))
          end
        end
      end
    end
  end

  def qbd_account_payment_to_delete_receive_payment_xml(xml, account_payment_hash, match = nil)
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
        payment_method.fetch(:name, 'Other')
      end
    end
  end

  def qbd_account_payment_ref_number(account_payment_hash)
    pm = account_payment_hash.fetch(:payment_method, {})
    if pm.fetch(:credit_card)
      account_payment_hash.fetch(:number, '')
    else
      account_payment_hash.fetch(:ref_number, '')
    end
  end

  def qbd_receive_payment_xml_to_account_payment(response, account_payment_hash)
    account_payment = self.company.account_payments.find_by_id(account_payment_hash.fetch(:id))
    xpath_base = '//QBXML/QBXMLMsgsRs/ReceivePaymentQueryRs/ReceivePaymentRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ReceivePaymentRet", {})
    qbd_receive_payment_hash_to_account_payment(qbd_hash, account_payment)
    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_receive_payment?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ReceivePaymentRs/ReceivePaymentRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ReceivePaymentRet", {})

    qbd_receive_payment_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_receive_payment_create_account_payment_sub_steps(qbd_hash)
    qbd_receive_payment_find_or_assign_associated_opts(qbd_hash)
    if self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
      qbd_receive_payment_hash_to_account_payment(qbd_hash)
    end
  end

  def qbd_receive_payment_hash_to_account_payment(qbd_hash, account_payment = nil)
    if account_payment.nil?
      account_payment = qbd_account_payment_find_by_name(qbd_hash.fetch('RefNumber', nil))
      account_payment ||= self.company.account_payments.new(
        channel: 'qbd',
        number: Spree::AccountPayment.number_from_integration(qbd_hash.fetch('RefNumber', nil), self.company.id),
        txn_id: qbd_hash.fetch('RefNumber', nil),
        currency: self.company.try(:currency)
      )
    end
    account_payment.amount = qbd_hash.fetch('TotalAmount', 0)
    account_payment.payment_date = qbd_hash.fetch('TxnDate', nil)

    # NOTE ReceivePaymentRet will include an unused payment in cases such as these:
    #   The sum of the PaymentAmount amounts is less than TotalAmount.
    #   A payment is received for the exact amount of an invoice, but a credit or a discount (or both) are set.
    account_payment.credit_amount = qbd_hash.fetch('UnusedPayment', 0)

    # NOTE QBD also has an UnusedCredits
    # ReceivePaymentRet will include an unused credit if the AppliedAmount of a
    # SetCredit aggregate is less than the amount of credit available for the specified CreditTxnID.

    account_payment.memo = qbd_hash.fetch('Memo', '')

    transaction do
      qbd_receive_payment_find_or_assign_associated_opts(qbd_hash, account_payment) #get sums
      account_payment.save!
      account_payment.process_and_capture
      qbd_receive_payment_find_or_assign_associated_opts(qbd_hash, account_payment) #process individual payments
    end

    qbd_create_or_update_match(account_payment,
                              'Spree::AccountPayment',
                              qbd_hash.fetch('TxnID'),
                              'ReceivePayment',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
  end

  def qbd_receive_payment_find_or_assign_associated_opts(qbd_hash, account_payment = nil)
    account = qbd_find_account_by_id_or_name(qbd_hash, 'CustomerRef')
    # TODO
    payment_method = self.company.payment_methods.where(
      name: qbd_hash.fetch('PaymentMethodRef', {}).fetch('FullName', 'Other')
    ).first_or_create do |method|
                        method.auto_capture = true
                        method.display_on = 'hidden'
                        method.type = 'Spree::PaymentMethod::Other'
                      end
    errors = []
    txns = {}
    [qbd_hash.fetch('AppliedToTxnRet', [])].flatten.each do |txn_line|
      begin
        ref_number = txn_line.fetch('RefNumber', nil)
        txn_type = txn_line.fetch('TxnType', nil)
        txn_id = txn_line.fetch('TxnID')
        case txn_type
        when 'Invoice'
          order = qbd_find_order_by_id_or_name(txn_line, nil, 'Invoice')
          txns[:orders] ||= []
          order_data = {
                         'order_id' => order.id,
                         'amount' => txn_line.fetch('Amount').to_d
                       } unless order.nil?
          if txn_line.fetch('LinkedTxn', nil).present?
            linked_txns = {}
            [txn_line.fetch('LinkedTxn', [])].flatten.each do |linked_txn|
              linked_ref_number = linked_txn.fetch('RefNumber', nil)
              linked_txn_type = linked_txn.fetch('TxnType', nil)
              linked_txn_id = linked_txn.fetch('TxnID')
              case linked_txn_type
              when 'CreditMemo'
                credit_memo = qbd_find_credit_memo_by_id_or_name(txn_line, 'LinkedTxn')
                linked_txns[:credit_memos] ||= []
                linked_txns[:credit_memos] << {
                                         'credit_memo_id' => credit_memo.id,
                                         'amount' => (linked_txn.fetch('Amount').to_d * -1) #credit amount is sent as a negative number
                                       } unless credit_memo.nil?
              when 'ReceivePayment'
                next # skip over other payments linked to the invoice
              else
                raise "Linked transactions of type #{linked_txn_type} are not supported. TxnID: #{linked_txn_id} / RefNumber: #{linked_ref_number}"
              end
            end
            order_data[:credit_memos] = linked_txns[:credit_memos] if linked_txns[:credit_memos].present?
          end
          txns[:orders] << order_data
        # when 'CreditMemo'
        #   credit_memo = qbd_find_credit_memo_by_id_or_name(txn_line, 'LinkedTxn')
        #   if account_payment
        #     txns[:credit_memos] ||= {}
        #     txns[:credit_memos] << {
        #                              'credit_memo_id' => credit_memo.id,
        #                              'amount' => txn_line.fetch('Amount').to_d
        #                            }# unless credit_memo.nil?
        #   end
        else
          raise "Applied to transactions of type '#{txn_type}' are not supported. TxnID: #{txn_id} / RefNumber: #{ref_number}"
        end
      rescue Exception => e
        errors << e.message
      end
    end #end txn_line loop

    if errors.present?
      raise errors.join("\n")
    end

    if account_payment.try(:persisted?)

      txns.each do |type, data|
        #data is an Array
        case type
        when :orders
          data.map! do |order_data| #{order_id: integer, amount: decimal, credit_memos: array}
            if order_data[:credit_memos].present?
              order_data['amount'] += order_data[:credit_memos].inject(0){|sum, memo_hash| sum += memo_hash['amount']}
              account_payment.add_credit_memos(order_data[:credit_memos])
            end

            order_data
          end
          account_payment.add_and_process_child_payments(data)

        when :credit_memos
          account_payment.add_credit_memos(data)
        end
      end
    elsif account_payment
      account_payment.account = account
      account_payment.payment_method = payment_method
      data = txns.fetch(:orders, [])
      data.map! do |order_data| #{order_id: integer, amount: decimal, credit_memos: array}
        if order_data[:credit_memos].present?
          order_data['amount'] += order_data[:credit_memos].inject(0){|sum, memo_hash| sum += memo_hash['amount']}
        end

        order_data
      end
      account_payment.orders_amount_sum = data.inject(0) do |sum, order_data|
        sum += order_data.fetch('amount', 0)
      end
    end

  end

  def qbd_account_payment_find_by_name(ref_number, channel = nil)
    account_payment = self.company.account_payments.where(
      number: Spree::AccountPayment.number_from_integration(ref_number, self.company.id)
    ).first
  end

  def qbd_account_payment_query_step_hash(account_payment_id)
    { step_type: :query, next_step: :skip, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
  end
  def qbd_account_payment_create_step_hash(account_payment_id)
    { step_type: :create, run_callbacks: true, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
  end
  def qbd_account_payment_push_step_hash(account_payment_id)
    { step_type: :push, run_callbacks: true, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
  end
  def qbd_account_payment_pull_step_hash(account_payment_id)
    { step_type: :pull, run_callbacks: true, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
  end
  def qbd_account_payment_delete_step_hash(account_payment_id)
    { step_type: :delete, run_callbacks: true, object_id: account_payment_id, object_class: 'Spree::AccountPayment', sync_type: 'ReceivePayment', qbxml_class: 'ReceivePayment', qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID'}
  end

  def qbd_receive_payment_query_xml(xml)
    xml.IncludeLineItems true
  end

  def qbd_account_payment_create(qbd_hash, qbxml_class)
    Sidekiq::Client.push(
      'class' => PullObjectWorker,
      'queue' => 'integrations',
      'args' => [
        self.integration_item_id,
        'Spree::AccountPayment',
        qbxml_class,
        qbd_hash.fetch('TxnID'),
        qbd_hash.fetch('RefNumber', nil)
      ]
    )

    return
  end

  def qbd_create_payment_callback_steps(payment_id)
    return unless self.integration_item.qbd_use_external_balance
    account_payment_hash = Spree::AccountPayment.find(payment_id).to_integration
    # qbd_create_step(
    #   self.qbd_account_step(account_payment_hash.fetch(:account_id)).merge(force_create: true)
    # )

    # TODO fix to use integration steps rather than create new job

    self.company
        .customer_accounts
        .find_by_id(account_payment_hash.fetch(:account_id))
        .try(:notify_integration)
  end
end
