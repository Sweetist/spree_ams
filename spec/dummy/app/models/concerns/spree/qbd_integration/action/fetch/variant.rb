module Spree::QbdIntegration::Action::Fetch::Variant
  def qbd_get_variants(integration_action)
    { status: 0, log: I18n.t('integrations.pull_products.label') }
  end

  def qbd_variant_get_step
    item_types = self.integration_item.qbd_pull_item_types_arr
    if item_types.blank?
      raise "No item types selected to pull"
    end

    %w[bundle inventory_assembly inventory_item service other_charge non_inventory_item].each do |item_type|
      #steps will be executed as a stack (LIFO)
      next unless item_types.include?(item_type)
      qbxml_class = qbd_variant_type_to_qbxml_class(item_type)
      query_by = qbxml_class == 'ItemGroup' ? 'Name' : 'FullName'
      qbd_create_step(
        {
          step_type: :query, object_class: 'Spree::Variant', qbxml_class: qbxml_class,
          qbxml_query_by: query_by, qbxml_match_by: 'ListID', iterator: 'Start'
        }
      )
    end

    next_integration_step.details
  end

  def qbd_pull_variant
    { status: 0, log: "Pull Product - #{self.sync_fully_qualified_name}" }
  end

  def qbd_variant_pull_step
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_type: 'Spree::Variant',
      sync_id: self.sync_id,
      sync_type: self.sync_type
    )

    if match.integration_syncable_id.present?
      return qbd_variant_step(match.integration_syncable_id)
    else
      {
        step_type: :pull, object_class: 'Spree::Variant', qbxml_class: self.sync_type,
        qbxml_query_by: 'ListID', qbxml_match_by: 'ListID', sync_id: self.sync_id
      }
    end
  end

  def qbd_variant_modified_range_xml(xml)
    return xml if self.integration_item.try(:qbd_export_list_to_csv)
    xml.FromModifiedDate (self.integration_item.last_pulled_at('Spree::Variant').to_datetime - 1.day)
    # xml.ToModifiedDate Not implemented

    xml
  end
end
