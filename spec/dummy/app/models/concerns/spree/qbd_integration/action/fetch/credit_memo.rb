module Spree::QbdIntegration::Action::Fetch::CreditMemo
  def qbd_get_credit_memos(integration_action)
    { status: 0, log: I18n.t('integrations.pull_credit_memos.label') }
  end

  def qbd_credit_memo_get_step
    qbxml_class = 'CreditMemo'
    qbd_create_step(
      {
        step_type: :query, object_class: 'Spree::CreditMemo', qbxml_class: qbxml_class,
        qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID', iterator: 'Start'
      }
    )

    next_integration_step.details
  end

  def qbd_pull_credit_memo
    { status: 0, log: "Pull CreditMemo - #{self.sync_fully_qualified_name}" }
  end

  def qbd_credit_memo_pull_step
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::CreditMemo',
      sync_id: self.sync_id,
      sync_type: self.sync_type
    )

    if match.integration_syncable_id.present?
      return qbd_credit_memo_step(match.integration_syncable_id)
    else
      {
        step_type: :pull, object_class: 'Spree::CreditMemo', qbxml_class: self.sync_type,
        qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID', sync_id: self.sync_id
      }
    end
  end

  def qbd_credit_memo_modified_range_xml(xml)
    if self.integration_item.try(:qbd_filter_by_transaction_date)
      xml.TxnDateRangeFilter do
        xml.FromTxnDate (self.integration_item.last_pulled_at('Spree::CreditMemo').to_datetime - 1.day).to_date.to_s
        # xml.ToModifiedDate Not implemented
      end
    else
      xml.ModifiedDateRangeFilter do
        xml.FromModifiedDate (self.integration_item.last_pulled_at('Spree::CreditMemo').to_datetime - 1.day)
        # xml.ToModifiedDate Not implemented
      end
    end

    xml
  end
end
