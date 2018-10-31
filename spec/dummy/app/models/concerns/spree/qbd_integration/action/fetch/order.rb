module Spree::QbdIntegration::Action::Fetch::Order
  def qbd_get_orders(integration_action)
    { status: 0, log: I18n.t('integrations.pull_orders.label') }
  end

  def qbd_order_get_step
    # TODO use other types than invoice
    order_types = ['invoice'] #self.integration_item.qbd_pull_order_types_arr
    if order_types.blank?
      raise "No order types selected to pull"
    end

    order_types.each do |order_type|

      #steps will be executed as a stack (LIFO)
      next unless order_types.include?(order_type)
      qbxml_class = order_type.camelize
      qbd_create_step(
        {
          step_type: :query, object_class: 'Spree::Order', qbxml_class: qbxml_class,
          qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID', iterator: 'Start'
        }
      )
    end

    next_integration_step.details
  end

  def qbd_pull_order
    { status: 0, log: "Pull Order - #{self.sync_fully_qualified_name}" }
  end

  def qbd_order_pull_step
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::Order',
      sync_id: self.sync_id,
      sync_type: self.sync_type
    )

    if match.integration_syncable_id.present?
      return qbd_order_step(match.integration_syncable_id)
    else
      {
        step_type: :pull, object_class: 'Spree::Order', qbxml_class: self.sync_type,
        qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID', sync_id: self.sync_id
      }
    end
  end

  def qbd_order_modified_range_xml(xml)
    if self.integration_item.try(:qbd_filter_by_transaction_date)
      xml.TxnDateRangeFilter do
        xml.FromTxnDate (self.integration_item.last_pulled_at('Spree::Order').to_datetime - 1.day).to_date.to_s
        # xml.ToModifiedDate Not implemented
      end
    else
      xml.ModifiedDateRangeFilter do
        xml.FromModifiedDate (self.integration_item.last_pulled_at('Spree::Order').to_datetime - 1.day)
        # xml.ToModifiedDate Not implemented
      end
    end

    xml
  end
end
