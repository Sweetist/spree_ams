module Spree::QbdIntegration::Action::StockTransfer
  #
  # Stock Transfer
  #
  def qbd_stock_transfer_step(stock_transfer_id, parent_step_id = nil)
    stock_transfer = Spree::StockTransfer.find(stock_transfer_id)
    stock_transfer_hash = stock_transfer.to_integration(
        self.integration_item.integrationable_options_for(stock_transfer)
      )

    case stock_transfer_hash.fetch(:transfer_type)
    when 'adjustment'
      adjustment_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_id, integration_syncable_type: 'Spree::StockTransferAdjustment')
      if adjustment_match.sync_id.blank?
        next_step = { step_type: :create, direction: :in, object_id: stock_transfer_id, object_class: 'Spree::StockTransferAdjustment', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      else
        # { step_type: :query, next_step: :skip, object_id: stock_transfer_id, object_class: 'Spree::StockTransferAdjustment', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
        next_step = { step_type: :terminate, next_step: :skip, object_id: stock_transfer_id, object_class: 'Spree::StockTransferAdjustment', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      end
    when 'transfer'
      # NOTE we cannot support InvetoryTransfer via api without row/bin information
      # transfer_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_id, integration_syncable_type: 'Spree::StockTransfer')
      # if transfer_match.sync_id.blank?
      #   { step_type: :create, next_step: :skip, direction: :in, object_id: stock_transfer_id, object_class: 'Spree::StockTransfer', qbxml_class: 'TransferInventory', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      # else
      #   # { step_type: :query, next_step: :skip, object_id: stock_transfer_id, object_class: 'Spree::StockTransferAdjustment', qbxml_class: 'TransferInventory', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      #   { step_type: :terminate, next_step: :skip, object_id: stock_transfer_id, object_class: 'Spree::StockTransfer', qbxml_class: 'TransferInventory', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      # end

      # create adjustments because we can't support transfer
      out_match = nil
      if stock_transfer_hash.fetch(:source_location_id)
        out_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_id, integration_syncable_type: 'Spree::StockTransferOut')
      end
      in_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_id, integration_syncable_type: 'Spree::StockTransferIn')

      if out_match && out_match.sync_id.to_s.empty?
        next_step = { step_type: :create, next_step: :continue, direction: :out, object_id: stock_transfer_id, object_class: 'Spree::StockTransferOut', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      elsif in_match.sync_id.to_s.empty?
        next_step = { step_type: :create, next_step: :skip, direction: :in, object_id: stock_transfer_id, object_class: 'Spree::StockTransferIn', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      else
        next_step = { step_type: :terminate, next_step: :skip, object_id: stock_transfer_id, object_class: 'Spree::StockTransferIn', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
      end

    when 'build'
      if self.integration_item.qbd_use_assemblies
        build_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_id, integration_syncable_type: 'Spree::StockTransferBuild')
        if build_match.sync_id.blank? && self.integration_item.qbd_use_assemblies
          next_step = { step_type: :create, next_step: :skip, direction: :in, object_id: stock_transfer_id, object_class: 'Spree::StockTransferBuild', qbxml_class: 'BuildAssembly', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
        else
          next_step = { step_type: :terminate, next_step: :skip, object_id: stock_transfer_id, object_class: 'Spree::StockTransferAdjustment', qbxml_class: 'BuildAssembly', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
        end
      else
        out_match = nil
        if stock_transfer_hash.fetch(:source_location_id)
          out_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_id, integration_syncable_type: 'Spree::StockTransferOut')
        end
        in_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_id, integration_syncable_type: 'Spree::StockTransferIn')

        if out_match && out_match.sync_id.to_s.empty?
          next_step = { step_type: :create, next_step: :continue, direction: :out, object_id: stock_transfer_id, object_class: 'Spree::StockTransferOut', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
        elsif in_match.sync_id.to_s.empty?
          next_step = { step_type: :create, next_step: :skip, direction: :in, object_id: stock_transfer_id, object_class: 'Spree::StockTransferIn', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
        else
          next_step = { step_type: :terminate, next_step: :skip, object_id: stock_transfer_id, object_class: 'Spree::StockTransferIn', qbxml_class: 'InventoryAdjustment', qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID'}
        end
      end
    end

    transfer_step = qbd_create_step(next_step)

    # Sync stock transfer account ref
    if stock_transfer_hash.fetch(:general_account_id)
      account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:general_account_id), integration_syncable_type: 'Spree::ChartAccount')
      if account_match.synced_at.nil? || account_match.synced_at < Time.current - 2.minute
        qbd_create_step(
          self.qbd_chart_account_step(account_match.integration_syncable_id),
          transfer_step.try(:id)
        )
      end
    elsif stock_transfer_hash.fetch(:transfer_type) == 'build' && !self.integration_item.qbd_use_assemblies
      account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: self.integration_item.qbd_build_assembly_account_id, integration_syncable_type: 'Spree::ChartAccount')
      if account_match.synced_at.nil? || account_match.synced_at < Time.current - 2.minute
        qbd_create_step(
          self.qbd_chart_account_step(account_match.integration_syncable_id),
          transfer_step.try(:id)
        )
      end
    end

    # Sync Variants (Destination Items covers Transfer & New Items)
    stock_transfer_hash.fetch(:destination_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      if variant_match.synced_at.nil? || variant_match.synced_at < Time.current - 2.minute
        qbd_create_step(
          self.qbd_variant_step(variant_match.integration_syncable_id),
          transfer_step.try(:id)
        )
      end
    end

    # Synchronize Source Stock Location
    if self.integration_item.qbd_use_multi_site_inventory
      if stock_transfer_hash.fetch(:source_location_id)
        stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:source_location_id), integration_syncable_type: 'Spree::StockLocation')
        if stock_location_match.synced_at.nil? || stock_location_match.synced_at < Time.current - 2.minute
          qbd_create_step(
            self.qbd_stock_location_step(stock_location_match.integration_syncable_id),
            transfer_step.try(:id)
          )
        end
      end

      # Synchronize Destination Stock Location
      if stock_transfer_hash.fetch(:destination_location_id)
        stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:destination_location_id), integration_syncable_type: 'Spree::StockLocation')
        if stock_location_match.synced_at.nil? || stock_location_match.synced_at < Time.current - 2.minute
          qbd_create_step(
            self.qbd_stock_location_step(stock_location_match.integration_syncable_id),
            transfer_step.try(:id)
          )
        end
      end
    end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_stock_transfer_out_to_inventory_adjustment_xml(xml, stock_transfer_hash, match = nil)
    qbd_stock_transfer_adjustment_to_inventory_adjustment_xml(xml, stock_transfer_hash, match)
  end

  def qbd_stock_transfer_in_to_inventory_adjustment_xml(xml, stock_transfer_hash, match = nil)
    qbd_stock_transfer_adjustment_to_inventory_adjustment_xml(xml, stock_transfer_hash, match)
  end

  def qbd_stock_transfer_adjustment_to_inventory_adjustment_xml(xml, stock_transfer_hash, match = nil)
    if match
      xml.TxnID     match.fetch(:sync_id)
      xml.EditSequence  match.fetch(:sync_alt_id)
    end

    xml.AccountRef do
      if stock_transfer_hash.fetch(:transfer_type) == 'build'
        account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: self.integration_item.qbd_build_assembly_account_id, integration_syncable_type: 'Spree::ChartAccount')
      else
        account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:general_account_id), integration_syncable_type: 'Spree::ChartAccount')
      end
      xml.ListID    account_match.try(:sync_id)
    end
    xml.TxnDate        stock_transfer_hash.fetch(:created_at).to_date.to_s
    if stock_transfer_hash.fetch(:number)
      xml.RefNumber    stock_transfer_hash.fetch(:number)
    end
    unstock = step.fetch('object_class') == 'Spree::StockTransferOut'
    if unstock
      stock_location_hash = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:source_location_id), integration_syncable_type: 'Spree::StockLocation')
    else
      stock_location_hash = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:destination_location_id), integration_syncable_type: 'Spree::StockLocation')
    end
    if self.integration_item.qbd_use_multi_site_inventory
      xml.InventorySiteRef do
        xml.ListID  stock_location_hash.try(:sync_id)
      end
    end
    items_key = unstock ? :source_items : :destination_items
    stock_transfer_hash.fetch(items_key, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      xml.InventoryAdjustmentLineAdd do
        xml.ItemRef do
          xml.ListID  variant_match.try(:sync_id)
        end
        xml.QuantityAdjustment do
          xml.QuantityDifference line_item.fetch(:quantity)
        end
      end
    end
  end

  # Transfer Inventory cannot be supported without row/bin locations for InventorySite
  def qbd_stock_transfer_to_transfer_inventory_xml(xml, stock_transfer_hash, match = nil, step)
    if match
      xml.TxnID     match.fetch(:sync_id)
      xml.EditSequence  match.fetch(:sync_alt_id)
    end

    xml.TxnDate        stock_transfer_hash.fetch(:created_at).to_date.to_s
    if stock_transfer_hash.fetch(:number)
      xml.RefNumber    stock_transfer_hash.fetch(:number)
    end
    xml.FromInventorySiteRef do
      source_location_hash = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:source_location_id), integration_syncable_type: 'Spree::StockLocation')
      xml.ListID  source_location_hash.try(:sync_id)
    end
    xml.ToInventorySiteRef do
      destination_location_hash = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:destination_location_id), integration_syncable_type: 'Spree::StockLocation')
      xml.ListID  destination_location_hash.try(:sync_id)
    end
    unless qbd_stock_memo(stock_transfer_hash).blank?
      xml.Memo    qbd_stock_memo(stock_transfer_hash)
    end

    stock_transfer_hash.fetch(:destination_items, []).each do |line_item|
      variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
      xml.TransferInventoryLineAdd do
        xml.ItemRef do
          xml.ListID  variant_match.try(:sync_id)
        end
        # As of March 4, 2017 we cannot support sending row/bin locations
        xml.FromInventorySiteLocationRef do
          xml.ListID
        end
        xml.ToInventorySiteLocationRef do
          xml.ListID
        end
        xml.QuantityToTransfer line_item.fetch(:quantity)
      end
    end
  end

  def qbd_stock_transfer_build_to_build_assembly_xml(xml, stock_transfer_hash, match = nil, step)
    assembly_hash = stock_transfer_hash.fetch(:destination_items).detect{|item| item.fetch(:quantity) > 0 }
    if match
      xml.TxnID      match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    else
      xml.ItemInventoryAssemblyRef do
        assembly_id = assembly_hash.fetch(:variant_id)
        assembly_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: assembly_id, integration_syncable_type: 'Spree::Variant')
        xml.ListID  assembly_match.try(:sync_id)
      end
    end
    stock_location_hash = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:destination_location_id), integration_syncable_type: 'Spree::StockLocation')
    if self.integration_item.qbd_use_multi_site_inventory
      xml.InventorySiteRef do
        xml.ListID  stock_location_hash.try(:sync_id)
      end
    end
    xml.TxnDate        stock_transfer_hash.fetch(:created_at).to_date.to_s
    if stock_transfer_hash.fetch(:number)
      xml.RefNumber    stock_transfer_hash.fetch(:number)
    end
    unless qbd_stock_memo(stock_transfer_hash).blank?
      xml.Memo    qbd_stock_memo(stock_transfer_hash)
    end
    xml.QuantityToBuild   assembly_hash.fetch(:quantity)
    xml.MarkPendingIfRequired   false
  end

  def qbd_inventory_adjustment_xml_to_stock_transfer(response, stock_transfer_hash, step)
    {}
  end

  def qbd_stock_memo(stock_transfer_hash)
    reference = ''
    reference += "Reference: #{stock_transfer_hash.fetch(:memo, nil)}" if stock_transfer_hash.fetch(:memo, nil).present?
    note = stock_transfer_hash.fetch(:note, '')
    [reference, note].reject(&:blank?).join("\n\n")
  end

end
