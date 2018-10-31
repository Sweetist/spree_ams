module Spree::QbdIntegration::Action::Fetch::ChartAccount
  def qbd_get_chart_accounts(integration_action)
    { status: 0, log: I18n.t('integrations.qbd.chart_accounts.label') }
  end

  def qbd_chart_account_get_step
    qbxml_class = 'Account'
    {
      step_type: :query, object_class: 'Spree::ChartAccount', qbxml_class: qbxml_class,
      qbxml_query_by: 'FullName', qbxml_match_by: 'ListID', iterator: 'Start'
    }
  end

  def qbd_pull_chart_account
    { status: 0, log: "Pull Chart Account - #{self.sync_fully_qualified_name}" }
  end

  def qbd_chart_account_pull_step
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::ChartAccount',
      sync_id: self.sync_id,
      sync_type: self.sync_type
    )

    if match.integration_syncable_id.present?
      return qbd_chart_account_step(match.integration_syncable_id)
    else
      {
        step_type: :pull, object_class: 'Spree::ChartAccount', qbxml_class: self.sync_type,
        qbxml_query_by: 'ListID', qbxml_match_by: 'ListID'
      }
    end
  end
end
