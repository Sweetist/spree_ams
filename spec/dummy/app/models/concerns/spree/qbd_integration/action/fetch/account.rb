module Spree::QbdIntegration::Action::Fetch::Account
  def qbd_get_accounts(integration_action)
    { status: 0, log: I18n.t('integrations.pull_customers.label') }
  end

  def qbd_account_get_step
    qbxml_class = 'Customer'
    qbd_create_step(
      {
        step_type: :query, object_class: 'Spree::Account', qbxml_class: qbxml_class,
        qbxml_query_by: 'FullName', qbxml_match_by: 'ListID', iterator: 'Start'
      }
    )

    next_integration_step.details
  end

  def qbd_pull_account
    { status: 0, log: "Pull Customer - #{self.sync_fully_qualified_name}" }
  end

  def qbd_account_pull_step
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::Account',
      sync_id: self.sync_id,
      sync_type: self.sync_type
    )

    if match.integration_syncable_id.present?
      return qbd_account_step(match.integration_syncable_id)
    else
      {
        step_type: :pull, object_class: 'Spree::Account', qbxml_class: self.sync_type,
        qbxml_query_by: 'ListID', qbxml_match_by: 'ListID', sync_id: self.sync_id
      }
    end
  end

  def qbd_account_modified_range_xml(xml)
    xml.FromModifiedDate (self.integration_item.last_pulled_at('Spree::Account').to_datetime - 1.day)
    # xml.ToModifiedDate Not implemented

    xml
  end
end
