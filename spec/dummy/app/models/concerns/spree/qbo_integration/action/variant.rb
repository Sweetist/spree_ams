module Spree::QboIntegration::Action::Variant
  # Synchronize Variant

  def qbo_synchronize_variant(variant_id, variant_class, is_transfer = false)
    variant = Spree::Variant.find(variant_id)
    variant_hash = variant.to_integration(
        self.integration_item.integrationable_options_for(variant)
      )

    # Master
    # don't sync master if variant is master or using categories in quickbooks
    if !variant_hash.fetch(:is_master) && !self.integration_item.qbo_use_categories
      sync_master = self.qbo_synchronize_variant(variant_hash.fetch(:master).try(:id), 'Spree::Variant')
      if sync_master.fetch(:status)
        master = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: variant_hash.fetch(:master).try(:id), integration_syncable_type: 'Spree::Variant')
      else
        return sync_master
      end
    end
    # Variant
    if self.integration_item.qbo_use_categories && !variant_hash.fetch(:is_master)
      categories = variant_hash.fetch(:fully_qualified_name).to_s.split(':').slice(0..-2)
      last_category = categories.last
      full_category_name = ''
      categories.each_with_index do |name, idx|
        full_category_name += name
        cat_status = qbo_synchronize_category(name, full_category_name, variant_hash)
        return cat_status if cat_status.fetch(:status) == -1
        full_category_name += ':'
      end
    end

    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:self).try(:id), integration_syncable_type: 'Spree::Variant')
    service = self.integration_item.qbo_service('Item')
    if match.sync_id
      # we have match, push data
      qbo_item = service.fetch_by_id(match.sync_id)
      qbo_update_item(qbo_item, variant_hash, is_transfer, service)
    else
      # try to match by name
      if self.integration_item.qbo_match_with_name
        qbo_item = service.query("select * from Item where type in ('Inventory', 'NonInventory', 'Service', 'Group') and FullyQualifiedName='#{self.qbo_safe_string(variant_hash.fetch(:fully_qualified_name))}'").first
      else
        # SKU
        qbo_item = service.find_by(:sku, self.qbo_safe_string(variant_hash.fetch(:sku))).first
      end
      if qbo_item
        # we have a match, save ID
        match.sync_id = qbo_item.id
        match.sync_type = qbo_item.class.to_s
        match.save
        qbo_update_item(qbo_item, variant_hash, is_transfer, service)
      else
        # no match & not a bundle - bundle create is not supported by QBO API as of Feb 2017
        if self.integration_item.qbo_create_related_objects && BUNDLE_TYPES.has_key?(variant_hash[:variant_type])
          { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} => Unable to find Match. Creating Bundle items is not currently supported by Quickbooks API." }
        elsif self.integration_item.qbo_create_related_objects
          # no match, create new!
          qbo_new_item = qbo_variant_to_qbo(Quickbooks::Model::Item.new, variant_hash, is_transfer)
          # Set master for variant
          unless variant_hash.fetch(:is_master)
            qbo_new_item.sub_item = true
            if self.integration_item.qbo_use_categories
              if last_category == variant_hash.fetch(:product).fetch(:name)
                parent_id = self.integration_item.integration_sync_matches.where(
                  integration_syncable_id: variant_hash.fetch(:product_id),
                  integration_syncable_type: 'Spree::Product').first.try(:sync_id)
              else
                parent_id = qbo_category_option_value_match(last_category, variant_hash).try(:sync_id)
              end
              qbo_new_item.parent_ref = Quickbooks::Model::BaseReference.new(parent_id)
            else
              qbo_new_item.parent_ref = Quickbooks::Model::BaseReference.new(master.try(:sync_id))
            end
          end
          if qbo_new_item.type == 'Inventory'
            # use earliest date between available_on and now
            qbo_new_item.inv_start_date ||= variant_hash.fetch(:available_on) < Time.current ? variant_hash.fetch(:available_on) : Time.current
            qbo_new_item.quantity_on_hand ||= 0 #starting qty is required
          end
          response = service.create(qbo_new_item)
          match.sync_id = response.id
          match.sync_type = response.class.to_s
          match.save
          { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} => Pushed." }
        else
          # no match, no create
          { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} => Unable to find Match" }
        end
      end
    end
  rescue Exception => e
    { status: -1, log: "#{e.class} - #{e.message}",
      backtrace: e.try(:backtrace) }
  end

  def qbo_update_item(qbo_item, variant_hash, is_transfer, service)
    if self.integration_item.qbo_variant_overwrite_conflicts_in == 'quickbooks'
      qbo_quantity_on_hand = qbo_item.quantity_on_hand
      # keeping qbo_variant_to_qbo before the IF condition allows the parts to sync
      qbo_updated_item = qbo_variant_to_qbo(qbo_item, variant_hash, is_transfer)

      if BUNDLE_TYPES.has_key?(variant_hash[:variant_type])
        # status 3: warn that update is not supported
        { status: 3, log: "#{variant_hash.fetch(:name_for_integration)} => Updating bundles is not currently supported by Quickbooks API. Please make any changes directly in Quickbooks" }
      else
        #allow sending quantity when integration is on or none is set yet in QBO
        unless self.integration_item.qbo_track_inventory && is_transfer
          qbo_updated_item.quantity_on_hand = qbo_quantity_on_hand || 0
        end
          service.update(qbo_updated_item)
        { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} => Match updated in QBO." }
      end
    elsif self.integration_item.qbo_variant_overwrite_conflicts_in == 'sweet'
      if qbo_item.track_quantity_on_hand? && variant_hash.fetch(:track_inventory)
        site = variant_hash.fetch(:inventory_counts, []).select{|si| si.fetch(:stock_location_id).to_s == self.integration_item.qbo_track_inventory_from.to_s}.first
        if site
          site.fetch(:self).try(:set_count_on_hand, qbo_item.quantity_on_hand.to_f)
        end
      end
      if BUNDLE_TYPES.has_key?(variant_hash[:variant_type])
        # status 3: warn that update is not supported
        { status: 3, log: "#{variant_hash.fetch(:name_for_integration)} => Updating bundles is not currently supported by Quickbooks API. Please make any changes directly to the bundle and its parts in Sweet" }
      else
        variant_hash.fetch(:self).from_integration({
          product: self.qbo_item_to_product(qbo_item).compact,
          variant: self.qbo_item_to_variant(qbo_item).compact,
          price: qbo_item.unit_price,
          sub_item: self.qbo_item_to_option_value(qbo_item).compact
          })
          { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} => Match updated in Sweet." }
      end
    else
      { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} => No conflict resolution." }
    end
  end

end
