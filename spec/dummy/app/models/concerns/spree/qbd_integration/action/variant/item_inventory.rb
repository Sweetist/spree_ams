module Spree::QbdIntegration::Action::Variant::ItemInventory

  def qbd_variant_to_item_inventory_xml(xml, variant_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           (self.integration_item.qbd_match_with_name ? variant_hash.fetch(:name) : variant_hash.fetch(:sku)).to_s #CHAR LIMIT 31
    xml.IsActive       variant_hash.fetch(:active, true)
    if self.integration_item.qbd_sync_item_class?
      txn_class_id = variant_hash.fetch(:txn_class_id)
      if txn_class_id
        txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: txn_class_id, integration_syncable_type: 'Spree::TransactionClass')
        xml.ClassRef do
          xml.ListID     txn_class_match.try(:sync_id)
        end
      end
    end
    unless variant_hash.fetch(:is_master)
      master_id = variant_hash.fetch(:master).try(:id)
      parent_match = self.integration_item.integration_sync_matches.find_by(
        integration_syncable_id: master_id,
        integration_syncable_type: 'Spree::Variant'
      )
      xml.ParentRef do
        xml.ListID     parent_match.try(:sync_id)
      end
    end
    if variant_hash.fetch(:tax_category_id)
      category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
      # xml.IsTaxIncluded false
      xml.SalesTaxCodeRef do
        xml.ListID category_match.try(:sync_id)
      end
    end
    description = (self.integration_item.qbd_match_with_name ? variant_hash.fetch(:description) : variant_hash.fetch(:name))
    if description
      xml.SalesDesc      description.truncate(4095)
    end
    xml.SalesPrice     variant_hash.fetch(:price)
    if variant_hash.fetch(:income_account_id)
      xml.IncomeAccountRef do
        income_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:income_account_id), integration_syncable_type: 'Spree::ChartAccount')
        xml.ListID     income_account_match.try(:sync_id)
      end
    end
    if description
      xml.PurchaseDesc   description.truncate(4095)
    end
    xml.PurchaseCost   variant_hash.fetch(:cost_price)
    # if variant_hash.fetch(:tax_category_id)
    #   category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
    #   # xml.IsTaxIncluded false
    #   xml.PurchaseTaxCodeRef do
    #     xml.ListID category_match.try(:sync_id)
    #   end
    # end

    if variant_hash.fetch(:cogs_account_id)
      xml.COGSAccountRef do
        cogs_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:cogs_account_id), integration_syncable_type: 'Spree::ChartAccount')
        xml.ListID     cogs_account_match.try(:sync_id)
      end
    end
    if variant_hash.fetch(:asset_account_id)
      xml.AssetAccountRef do
        asset_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:asset_account_id), integration_syncable_type: 'Spree::ChartAccount')
        xml.ListID     asset_account_match.try(:sync_id)
      end
    end
    if step.fetch('step_type') == 'create'
      if self.integration_item.qbd_use_multi_site_inventory
        xml.QuantityOnHand 0
      else
        xml.QuantityOnHand variant_hash.fetch(:self).total_on_hand
      end
    end
    # Return XML
    xml
  end

  def qbd_item_inventory_xml_to_variant(response, variant_hash)
    variant = self.company.variants_including_master.find_by_id(variant_hash.fetch(:id))
    by_name = self.integration_item.qbd_match_with_name
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemInventoryQueryRs/ItemInventoryRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemInventoryRet", {})
    qbd_item_inventory_hash_to_variant(qbd_hash, variant.try(:product), variant)

    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_item_inventory?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemInventoryQueryRs/ItemInventoryRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemInventoryRet", {})

    qbd_inventory_item_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_item_inventory_create_variant_sub_steps(qbd_hash)
    if qbd_hash.fetch('ParentRef', nil)
      parent_match = self.integration_item.integration_sync_matches.where(
        integration_syncable_type: "Spree::Variant",
        sync_type: "ItemInventory",
        sync_id: qbd_hash.fetch('ParentRef', {}).fetch('ListID', nil)
      ).first
      product = parent_match.try(:integration_syncable).try(:product)
      if product.nil?
        if self.integration_item.qbd_match_with_name
          product = self.company.products.find_by_name(qbd_hash.fetch('FullName', '').split(':').first)
        else
          product = self.company.variants_including_master.where(
                    sku: qbd_hash.fetch('FullName', '').split(':').first,
                    is_master: true
                  ).first.try(:product)
        end
      end

      if product.nil?
        raise "Must sync parent item before creating variants"
        # TODO create sub_step for parent_item to create before creating variant
        # qbd_item_non_inventory_create_parent_variant(qbd_hash)
      end
    end
    qbd_inventory_item_find_or_assign_associated_opts(qbd_hash)
    if self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
      qbd_item_inventory_hash_to_variant(qbd_hash)
    end
  end

  def qbd_item_inventory_hash_to_variant(qbd_hash, product = nil, variant = nil)
    by_name = self.integration_item.qbd_match_with_name
    if product.nil?
      if qbd_hash.fetch('ParentRef', nil)
        parent_match = self.integration_item.integration_sync_matches.where(
          integration_syncable_type: "Spree::Variant",
          sync_type: "ItemInventory",
          sync_id: qbd_hash.fetch('ParentRef', {}).fetch('ListID', nil)
        ).first
        product = parent_match.try(:integration_syncable).try(:product)
      end
      if by_name
        product ||= self.company.products.find_by_name(qbd_hash.fetch('FullName', '').split(':').first)
      else
        product ||= self.company.variants_including_master.where(
                  sku: qbd_hash.fetch('FullName', '').split(':').first,
                  is_master: true
                ).first.try(:product)
      end
      product ||= self.integration_item.company.products.new
      variant = qbd_hash.fetch('FullName', '').include?(':') ? product.variants.new : product.master
    end
    date = qbd_hash.fetch('TimeCreated').to_date
    product.available_on ||= date
    product.shipping_category_id ||= self.integration_item.qbd_default_shipping_category_id
    product.product_type = 'inventory_item'
    variant.variant_type = 'inventory_item'

    unless qbd_hash.fetch('IsActive', false).to_bool
      time = Time.current
      variant.discontinued_on = time
      if product.variants
                .where('spree_variants.id != ?', variant.id)
                .where('spree_variants.discontinued_on is null').blank?
        product.discontinued_on = time
      end
    else
      variant.discontinued_on = nil
      product.discontinued_on = nil
    end

    if qbd_hash.fetch('SalesTaxCodeRef', nil)
      tax_category_id = qbd_tax_category_from_qbd_sales_tax_code(
        qbd_hash.fetch('SalesTaxCodeRef', {}).fetch('ListID', nil),
        qbd_hash.fetch('SalesTaxCodeRef', {}).fetch('FullName', nil)
      ).try(:id)
      if tax_category_id
        product.tax_category_id = tax_category_id
        variant.tax_category_id = tax_category_id
      end
    end

    desc = qbd_hash.fetch('SalesDesc', nil)
    desc ||= qbd_hash.fetch('PurchaseDesc', nil)

    if by_name
      product.name = qbd_hash.fetch('FullName', '').split(':').first
      product.description = desc if variant.is_master?
      variant.variant_description = desc
      variant.sku = qbd_hash.fetch('Name', '') if variant.sku.blank?
    else
      if variant.is_master?
        product.name = desc unless desc.blank?
        product.name = qbd_hash.fetch('Name', '') if desc.blank?
      end
      variant.sku = qbd_hash.fetch('Name', '')
    end

    if qbd_hash.fetch('SalesPrice', nil)
      variant.price = qbd_hash.fetch('SalesPrice', 0)
      product.for_sale = true
    else
      variant.price ||= 0
      product.for_sale = false
    end

    if qbd_hash.fetch('PurchaseCost', nil)
      variant.cost_price = qbd_hash.fetch('PurchaseCost', 0)
      product.for_purchase = true
    else
      variant.cost_price = 0
      product.for_purchase = false
    end

    qbd_inventory_item_find_or_assign_associated_opts(qbd_hash, variant, product)

    qbd_find_or_create_option_types_and_values(qbd_hash.fetch('FullName', ''), variant, product)
    product.save!
    variant.save!

    qbd_create_or_update_match(variant,
                              'Spree::Variant',
                              qbd_hash.fetch('ListID'),
                              'ItemInventory',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
  end

  def qbd_inventory_item_find_or_assign_associated_opts(qbd_hash, variant = nil, product = nil)
    income_account, cogs_account, assign_account, txn_class = nil, nil, nil, nil
    if qbd_hash.fetch('IncomeAccountRef', nil)
      income_account = qbd_find_chart_account_by_id_or_name(qbd_hash, 'IncomeAccountRef')
    end
    if qbd_hash.fetch('COGSAccountRef', nil)
      cogs_account = qbd_find_chart_account_by_id_or_name(qbd_hash, 'COGSAccountRef')
    end
    if qbd_hash.fetch('AssetAccountRef', nil)
      asset_account = qbd_find_chart_account_by_id_or_name(qbd_hash, 'AssetAccountRef')
    end
    if qbd_hash.fetch('ClassRef', nil)
      txn_class = qbd_find_transaction_class_by_id_or_name(qbd_hash)
    end

    if variant.present?
      variant.assign_account(income_account, 'income_account_id') if income_account
      variant.assign_account(cogs_account, 'cogs_account_id') if cogs_account
      variant.assign_account(asset_account, 'asset_account_id') if asset_account
      variant.txn_class_id = txn_class.try(:id)
    end

    product.assign_accounts_from_variant(variant) if product.present?
  end

  def qbd_item_inventory_to_csv(csv, item)
    csv << [
      'ItemInventory',
      item.fetch('FullName'),
      item.fetch('SalesDesc', nil),
      nil, # space saver for part FullName
      nil  # space saver for part QTY
    ]
  end

  def qbd_item_inventory_pull_step_hash

  end

end
