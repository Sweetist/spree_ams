module Spree::QbdIntegration::Action::Variant
  include Spree::QbdIntegration::Action::Variant::ItemInventoryAssembly
  include Spree::QbdIntegration::Action::Variant::ItemInventory
  include Spree::QbdIntegration::Action::Variant::ItemNonInventory
  include Spree::QbdIntegration::Action::Variant::ItemGroup
  include Spree::QbdIntegration::Action::Variant::ItemOtherCharge
  include Spree::QbdIntegration::Action::Variant::ItemService
  #
  # Variant
  #
  def qbd_variant_type_to_qbxml_class(variant_type)
    case variant_type
    when 'inventory_item'
      qbxml_class = 'ItemInventory'
    when 'inventory_assembly'
      if self.integration_item.qbd_use_assemblies
        qbxml_class = 'ItemInventoryAssembly'
      else
        qbxml_class = 'ItemInventory'
      end
    when 'non_inventory_item'
      qbxml_class = 'ItemNonInventory'
    when 'bundle'
      qbxml_class = 'ItemGroup'
    when 'service'
      qbxml_class = 'ItemService'
    when 'other_charge'
      qbxml_class = 'ItemOtherCharge'
    end
  end

  def qbd_variant_step(variant_id, parent_step_id = nil)
    variant = Spree::Variant.find(variant_id)
    if self.integration_item.qbd_match_with_name && variant.fully_qualified_name.split(':').count > 2
      raise "#{variant.fully_qualified_name} cannot be synced. Syncing items nested more than one level deep is only supported when matching by sku"
    end
    variant_hash = variant.to_integration(
        self.integration_item.integrationable_options_for(variant)
      )

    qbxml_class = qbd_variant_type_to_qbxml_class(variant_hash.fetch(:variant_type))

    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_id, integration_syncable_type: 'Spree::Variant')
    unless self.integration_steps.where(integrationable_type: 'Spree::Variant', integration_syncable_id: variant_id).first || self.current_step.present? || parent_step_id
      next_step = qbd_variant_query_step_hash(qbxml_class, variant_id, variant_hash.fetch(:master).try(:id)).merge({next_step: :continue})
      next_step.merge!({qbxml_query_by: 'ListID', sync_id: match.sync_id}) if match.sync_id.present?
      next_step = qbd_create_step(next_step, parent_step_id)
      next_step.update_columns(sync_id: match.sync_id)
      return next_step.details
    end

    if match.sync_id.nil?
      next_step = qbd_variant_query_step_hash(qbxml_class, variant_id, variant_hash.fetch(:master).try(:id))
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = qbd_variant_create_step_hash(qbxml_class, variant_id, variant_hash.fetch(:master).try(:id))
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_variant_push_step_hash(qbxml_class, variant_id, variant_hash.fetch(:master).try(:id))
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_variant_pull_step_hash(qbxml_class, variant_id, variant_hash.fetch(:master).try(:id))
      else
        next_step = qbd_variant_query_step_hash(qbxml_class, variant_id, variant_hash.fetch(:master).try(:id))
        next_step.merge!({next_step: :skip})
      end
    end

    variant_step = qbd_create_step(next_step, parent_step_id)

    if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
      if variant_hash.fetch(:track_inventory) && self.integration_item.qbd_track_inventory && self.integration_item.qbd_use_multi_site_inventory
        variant_hash.fetch(:inventory_counts, []).each do |inventory_count|
          # # Force Inventory Count
          # inventory_match = self.integration_item.integration_sync_matches.find_or_create_by(
          #   integration_syncable_id: inventory_count.fetch(:id),
          #   integration_syncable_type: 'Spree::StockItem'
          # )
          # if inventory_match.synced_at.nil? #|| inventory_match.synced_at < Time.current - 10.minute
          #   qbd_create_step(
          #     qbd_inventory_count_create_step_hash(inventory_count),
          #     variant_step.id
          #   )
          # end
          # Sync Stock Locations
          if inventory_count.fetch(:stock_location_id)
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(
              integration_syncable_id: inventory_count.fetch(:stock_location_id),
              integration_syncable_type: 'Spree::StockLocation'
            )
            if stock_location_match.synced_at.nil? || stock_location_match.synced_at < Time.current - 10.minute
              qbd_create_step(
                self.qbd_stock_location_step(stock_location_match.integration_syncable_id, variant_step.id),
                variant_step.id
              )
            end
          end
        end
      end
    elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
      if variant_hash.fetch(:track_inventory) && self.integration_item.qbd_track_inventory && self.integration_item.qbd_use_multi_site_inventory
        variant_hash.fetch(:inventory_counts, []).each do |inventory_count|
          # # Force Inventory Count
          # inventory_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: inventory_count.fetch(:id), integration_syncable_type: 'Spree::StockItem')
          # if inventory_match.synced_at.nil? || inventory_match.synced_at < Time.current - 10.minute
          #   adjustment_step = qbd_create_step(
          #     qbd_inventory_count_filter_step_hash(inventory_count),
          #     variant_step.id
          #   )
          # end
          # Sync Stock Locations
          if inventory_count.fetch(:stock_location_id)
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(
              integration_syncable_id: inventory_count.fetch(:stock_location_id),
              integration_syncable_type: 'Spree::StockLocation'
            )
            if stock_location_match.synced_at.nil? || stock_location_match.synced_at < Time.current - 10.minute
              qbd_create_step(
                self.qbd_stock_location_step(stock_location_match.integration_syncable_id, variant_step.id),
                variant_step.id
              )
            end
          end
        end
      end
    end

    unless variant_hash.fetch(:is_master)
      master_id = variant_hash.fetch(:master).try(:id)
      parent_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: master_id, integration_syncable_type: 'Spree::Variant')
      if parent_match.synced_at.nil? || parent_match.synced_at < Time.current - 10.minute
        qbd_create_step(
          self.qbd_variant_step(master_id, variant_step.id),
          variant_step.id
        )
      end
    end

    # Sync Tax Categories
    if variant_hash.fetch(:tax_category_id)
      category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
      if category_match.synced_at.nil? || category_match.synced_at < Time.current - 10.minute
        qbd_create_step(
          self.qbd_tax_category_step(category_match.integration_syncable_id, variant_step.id),
          variant_step.id
        )
      end
    end

    #Sync Chart of Accounts
    %w[income cogs asset expense].each do |type|
      next if variant_hash.fetch("#{type}_account_id".to_sym).blank?
      account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch("#{type}_account_id".to_sym), integration_syncable_type: 'Spree::ChartAccount')
      if account_match.synced_at.nil? || account_match.synced_at < Time.current - 10.minute
        qbd_create_step(
          self.qbd_chart_account_step(account_match.integration_syncable_id, variant_step.id),
          variant_step.id
        )
      end
    end

    #Sync TxnClass
    if self.integration_item.qbd_sync_item_class? && variant_hash.fetch(:txn_class_id)
      txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
      if txn_class_match.synced_at.nil? || txn_class_match.synced_at < Time.current - 10.minute
        qbd_create_step(
          self.qbd_transaction_class_step(txn_class_match.integration_syncable_id, variant_step.id),
          variant_step.try(:id)
        )
      end
    end

    #Sync Parts
    variant_hash.fetch(:parts_variants, []).each do |part_variant|
      part_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: part_variant.fetch(:part_id), integration_syncable_type: 'Spree::Variant')
      if part_match.synced_at.nil? || part_match.synced_at < Time.current - 10.minute
        qbd_create_step(
          self.qbd_variant_step(part_match.integration_syncable_id, variant_step.id),
          variant_step.id
        )
      end
    end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_stock_item_to_inventory_adjustment_xml(xml, stock_item_hash, match = nil)
    xml.AccountRef do
      xml.FullName     self.integration_item.vendor.chart_accounts.find_by_id(self.integration_item.vendor.variants_including_master.find_by_id(stock_item_hash.fetch(:variant_id)).try(:asset_account_id)).try(:name)
    end
    stock_location_hash = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_item_hash.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
    xml.InventorySiteRef do
      xml.ListID  stock_location_hash.try(:sync_id)
    end
    variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_item_hash.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
    xml.InventoryAdjustmentLineAdd do
      xml.ItemRef do
        xml.ListID  variant_match.try(:sync_id)
      end
      xml.QuantityAdjustment do
        xml.NewQuantity stock_item_hash.fetch(:count_on_hand)
      end
    end
  end

  def qbd_stock_item_to_item_sites_xml(xml, stock_item_hash, match = nil)
    xml.ItemSiteFilter do
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_item_hash.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      xml.ItemFilter do
        xml.ListID    variant_match.try(:sync_id)
      end
      stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_item_hash.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
      xml.SiteFilter do
        xml.ListID    stock_location_match.try(:sync_id)
      end
    end
  end

  def qbd_item_sites_xml_to_stock_item(response, stock_item_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemSitesQueryRs/ItemSitesRet'
    count_on_hand = response.xpath("#{xpath_base}/QuantityOnHand").try(:children).try(:text)
    stock_item_hash.fetch(:self).try(:set_count_on_hand, count_on_hand)
  end

  def qbd_variant_find_by_name(full_name)
    if self.integration_item.qbd_match_with_name
      variant = self.integration_item.company.variants_including_master.where(
        fully_qualified_name: full_name
      ).first
    else
      sku_arr = full_name.split(':')
      query = {sku: sku_arr.last}
      if sku_arr.length == 1
        query.merge!({is_master: true})
      end
      variant = self.integration_item
                    .company
                    .variants_including_master
                    .where(query).first
    end

    variant
  end

  def qbd_find_variant_by_id_or_name(hash, base_key)
    qbd_variant_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_variant_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_variant_id.present? || qbd_variant_full_name.present?

    variant_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::Variant',
      sync_id: qbd_variant_id
    ).first

    variant = self.company.variants_including_master.where(id: variant_match.try(:integration_syncable_id)).first
    if self.integration_item.qbd_match_with_name
      variant ||= self.company.variants_including_master.where(fully_qualified_name: qbd_variant_full_name).first
    else
      variant ||= self.company.variants_including_master.where(sku: qbd_variant_full_name.to_s.split(':').last).first
    end

    if variant.nil?
      raise "Could not find product #{qbd_variant_full_name} in Sweet. Please create the required item in Sweet manually or pull it from Quickbooks."
      # sync_step = self.integration_steps.find_or_initialize_by(
      #   integrationable_type: 'Spree::Account',
      #   sync_type: 'Customer',
      #   sync_id: qbd_account_id
      # )
      # sync_step.parent_id ||= self.current_step.try(:id)
      # sync_step.details = qbd_account_pull_step_hash.merge(
      #   {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_account_id, 'sync_full_name' => qbd_account_full_name}
      # )
      #
      # sync_step.save
    end

    variant
  end

  def qbd_variant_create(qbd_hash, qbxml_class)
    Sidekiq::Client.push(
      'class' => PullObjectWorker,
      'queue' => 'integrations',
      'args' => [
        self.integration_item.id,
        'Spree::Variant',
        qbxml_class,
        qbd_hash.fetch('ListID'),
        qbxml_class == 'ItemGroup' ? qbd_hash.fetch('Name') : qbd_hash.fetch('FullName')
      ]
    )

    return
  end

  def qbd_find_or_create_option_types_and_values(full_name, variant, product)
    return if full_name.to_s.split(':').length <= 1

    option_value_names = full_name.to_s.split(':').slice(1..-1)

    if option_value_names.length == 1 && variant.persisted? && product.option_types.blank?
      variant.pack_size = option_value_names.first
    else
      pots = product.product_option_types.order(position: :asc)
      ov_ids = variant.option_value_ids.slice(0..option_value_names.length)
      option_value_names.each_with_index do |ov_name, idx|
        next if self.company.option_values.where(name: ov_name, option_type_id: pots[idx].try(:option_type_id)).present?
        pots[idx].try(:destroy!)
        pos = idx + 1

        option_type = self.company.option_types.find_or_create_by!(presentation: "Option #{pos}", name: "Option #{pos}")
        ov = option_type.option_values.find_or_create_by!(name: ov_name, presentation: ov_name)
        ov.presentation = ov_name
        ov.save!
          #find or create option type by product name
        if product.id
          product.product_option_types.create(option_type_id: option_type.id, position: pos)
        else
          product.product_option_types.new(option_type_id: option_type.id, position: pos)
        end
        ov_ids[idx] = ov.id
      end
      variant.option_value_ids = ov_ids
    end

  end

  def qbd_item_csv_headers
    ['Item Type', 'Item Name', 'Item Desc', 'Part FullName', 'Part Qty']
  end

  def qbd_assign_parts(hash, line_type, part_ref_key, variant = nil)
    # Used for Assemblies and Group Items
    # expect 'ItemInventoryAssemblyLine' as line_type for assembly
    # expect 'ItemInventoryRef' as part_ref_key for assembly
    part_lines = hash.fetch(line_type, [])
    part_ids = []
    if part_lines.is_a?(Array)
      part_lines.each do |part_line|
        next if part_line.blank?
        part_ids << qbd_assign_part_line(variant, part_line, part_ref_key).try(:id)
      end
    elsif part_lines.is_a?(Hash) #this happens when there is only one part
      part_ids << qbd_assign_part_line(variant, part_lines, part_ref_key).try(:id)
    end
    part_ids = part_ids.compact
    if variant
      variant.parts_variants.where.not(part_id: part_ids).destroy_all
    end

    part_ids
  end

  def qbd_assign_part_line(variant, part_line, part_ref_key)
    # Used for Assemblies and Group Items
    qbd_part_id = part_line.fetch(part_ref_key, {}).fetch('ListID', nil)
    qbd_part_full_name = part_line.fetch(part_ref_key, {}).fetch('FullName', nil)
    part_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::Variant',
      sync_id: qbd_part_id
    ).first
    part = self.company.variants_including_master.where(id: part_match.try(:integration_syncable_id)).first

    if self.integration_item.qbd_match_with_name
      part ||= self.company.variants_including_master.where(fully_qualified_name: qbd_part_full_name).first
    else
      sku_arr = part_line.fetch(part_ref_key, {}).fetch('FullName', nil).to_s.split(':')
      if sku_arr.length > 1
        part ||= self.company.variants.where(
          is_master: false,
          sku: sku_arr.last
        ).first
      else
        part ||= self.company.variants_including_master.where(
          is_master: true,
          sku: sku_arr.last
        ).first
      end
    end

    if part.nil?
      # if part_ref_key == 'ItemInventoryRef'
      #   sync_step = self.integration_steps.find_or_initialize_by(
      #     integrationable_type: 'Spree::Variant',
      #     sync_type: part_ref_key.slice(0..-4),
      #     sync_id: qbd_part_id
      #   )
      #   sync_step.parent_id ||= self.current_step.try(:id)
      #   sync_step.details = qbd_variant_pull_step_hash('ItemInventory').merge(
      #     {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_part_id, 'sync_full_name' => qbd_part_full_name}
      #   )
      #
      #   sync_step.save
      # else

      # We cannot create from parts list because we do not have the product type
        raise "Unable to find item with full name #{qbd_part_full_name}. Creating products from Group & Assembly Items parts is not supported."
      # end
      return nil
    end

    if variant
      if part.nil?
        raise "Unable to find item with full name #{qbd_part_full_name}."
      end
      part.product.try(:update_columns, {can_be_part: true})
      part_variant = variant.parts_variants.find_or_initialize_by(part_id: part.id)
      part_variant.count = part_line.fetch('Quantity', 0)
      part_variant.save! if variant.id.present?
    end

    part
  end

  def qbd_variant_pull_step_hash(qbxml_class, variant_id = nil, master_id = nil)
    { step_type: :pull, object_id: variant_id, object_class: 'Spree::Variant', qbxml_class: qbxml_class, qbxml_query_by: 'FullName', qbxml_match_by: 'ListID', object_parent_id: master_id }
  end

  def qbd_variant_query_step_hash(qbxml_class, variant_id = nil, master_id = nil)
    { step_type: :query, object_id: variant_id, object_class: 'Spree::Variant', qbxml_class: qbxml_class, qbxml_query_by: 'FullName', qbxml_match_by: 'ListID', object_parent_id: master_id }
  end

  def qbd_variant_create_step_hash(qbxml_class, variant_id = nil, master_id = nil)
    { step_type: :create, next_step: :continue, object_id: variant_id, object_class: 'Spree::Variant', qbxml_class: qbxml_class, qbxml_query_by: 'FullName', qbxml_match_by: 'ListID', object_parent_id: master_id }
  end

  def qbd_variant_push_step_hash(qbxml_class, variant_id = nil, master_id = nil)
    { step_type: :push, object_id: variant_id, object_class: 'Spree::Variant', qbxml_class: qbxml_class, qbxml_query_by: 'FullName', qbxml_match_by: 'ListID', object_parent_id: master_id }
  end

  def qbd_inventory_count_create_step_hash(inventory_count)
    { step_type: :create, next_step: :continue, item_id: inventory_count.fetch(:id), object_id: inventory_count.fetch(:id), object_class: 'Spree::StockItem', qbxml_class: 'InventoryAdjustment', qbxml_match_by: 'TxnID' }
  end

  def qbd_inventory_count_filter_step_hash(inventory_count)
    { step_type: :filter, next_step: :continue, item_id: inventory_count.fetch(:id), object_id: inventory_count.fetch(:id), object_class: 'Spree::StockItem', qbxml_class: 'ItemSites', qbxml_match_by: 'ListID' }
  end

end
