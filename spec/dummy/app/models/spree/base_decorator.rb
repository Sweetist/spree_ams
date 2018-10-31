Spree::Base .class_eval do
  # Checking we should run sync trigger for that integration item?
  # response is hash object
  # { result: true }  - trigger integration sync
  # { result: false, reason: 'Some no sync reason' } - no trigger, write reason
  # in action_log
  def sync_for_item(item)
    return { result: true } unless respond_to?(:integration_sync_matches)
    return { result: true } if integration_sync_matches.blank?
    return { result: true } if integration_sync_matches
                               .find_by(integration_item: item)
                               .nil?
    return { result: true } unless integration_sync_matches
                                   .find_by(integration_item: item).no_sync

    { result: false, reason: I18n.t('integrations.prevents_infinite_update') }
  end

  def preference_label(key)
    Spree.t(key)
  end

  def self.restricted_view_editable_attributes
    []
  end

  def action
    #used for several models to handle bulk actions
  end
end
