module Spree::QboIntegration::Action::Category
  # Synchronize categories
  # There are 3 scenarios that we may have to sync to
  # 1. product name (top level category)
  # 2a. option value (sub category)
  # 2b. variant pack_size (sub category)

  def qbo_synchronize_category(name, fully_qualified_name, variant_hash)
    #Sync category to product name
    if name == fully_qualified_name
      parent_id = nil
      match = self.integration_item.integration_sync_matches.find_or_create_by(
        integration_syncable_id: variant_hash.fetch(:product_id),
        integration_syncable_type: 'Spree::Product')

    else #Sync category to option_values_variants
      if fully_qualified_name.split(':').count == 2
        parent_id = self.integration_item.integration_sync_matches.where(
          integration_syncable_id: variant_hash.fetch(:product_id),
          integration_syncable_type: 'Spree::Product').first.try(:sync_id)
      elsif fully_qualified_name.split(':').count > 2
        parent_match = qbo_category_option_value_match(fully_qualified_name.split(':')[-2], variant_hash)
        parent_id = parent_match.try(:sync_id)
      end

      match = qbo_category_option_value_match(name, variant_hash)
    end

    qbo_update_or_create_category(name, fully_qualified_name, variant_hash, match, parent_id)

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_category_option_value_match(ov_name, variant_hash)
    ov = variant_hash.fetch(:option_values).detect{|option| option[:presentation] == ov_name}
    ov ||= {}
    ovv = Spree::OptionValuesVariant.where(
      variant_id: variant_hash.fetch(:id),
      option_value_id: ov.fetch(:id, nil)
    ).first
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: ovv.try(:id),
      integration_syncable_type: 'Spree::OptionValuesVariant')
  end

  def qbo_update_or_create_category(name, fully_qualified_name, variant_hash, match, parent_id)
    service = self.integration_item.qbo_service('Item')

    if match.sync_id #match is found
      qbo_category = service.fetch_by_id(match.sync_id)
      #perform update
      qbo_update_category(qbo_category, name, variant_hash, parent_id, service)
    else
      # qbo_category = service.query("select * from Item where Type='Category' and name='#{self.qbo_safe_string(fully_qualified_name)}'").first
      qbo_category = nil
      qbo_item = service.query("select * from Item where type in ('Inventory', 'NonInventory', 'Service', 'Group') and FullyQualifiedName='#{self.qbo_safe_string(fully_qualified_name)}'").first
      # need to deactivate item with same name due to uniquness constraint
      if qbo_item
        item_service = self.integration_item.qbo_service('Item')
        qbo_item.active = false
        item_service.update(qbo_item)
      else
        qbo_category = service.query("select * from Item where type='Category' and FullyQualifiedName='#{self.qbo_safe_string(fully_qualified_name)}'").first
      end
      # try to match by name
      if qbo_category
        #nothing to update if we match fully_qualified_name of category
        # we have a match, save ID
        match.sync_id = qbo_category.id
        match.sync_type = qbo_category.class.to_s
        match.save
        { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} category => Matched." }
      elsif self.integration_item.qbo_create_related_objects
        # try to create
        qbo_new_category = qbo_category_to_qbo(Quickbooks::Model::Item.new, name, parent_id)
        response = service.create(qbo_new_category)
        match.sync_id = response.id
        match.sync_type = response.class.to_s
        match.save
        { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} category => Pushed." }
      else
        { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} category => Unable to find Match for #{name}" }
      end
    end
  end

  def qbo_update_category(qbo_category, name, variant_hash, parent_id, service)
    qbo_updated_category = qbo_category_to_qbo(qbo_category, name, parent_id)
    if self.integration_item.qbo_variant_overwrite_conflicts_in == 'quickbooks'
      service.update(qbo_updated_category)
      { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} category => Match updated in QBO." }
    elsif self.integration_item.qbo_variant_overwrite_conflicts_in == 'sweet'
      { status: 3, log: "#{variant_hash.fetch(:name_for_integration)} category => Not currently supported"}
    else
      { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} category => Category matched without update." }
    end
  end

  def qbo_category_to_qbo(qbo_category, name, parent_id)
    qbo_category.name = name
    qbo_category.type = 'Category'
    if parent_id
      qbo_category.sub_item = true
      qbo_category.parent_ref = Quickbooks::Model::BaseReference.new(parent_id)
    end

    qbo_category
  end

end
