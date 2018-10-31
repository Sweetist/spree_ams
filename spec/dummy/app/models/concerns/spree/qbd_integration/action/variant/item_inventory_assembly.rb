module Spree::QbdIntegration::Action::Variant::ItemInventoryAssembly

  def qbd_variant_to_item_inventory_assembly_xml(xml, variant_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           (self.integration_item.qbd_match_with_name ? variant_hash.fetch(:name) : variant_hash.fetch(:sku)).to_s.truncate(31)
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
    # xml.QuantityOnHand 0

    variant_hash.fetch(:parts_variants, []).each do |part_variant|
      part_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: part_variant.fetch(:part_id), integration_syncable_type: 'Spree::Variant')
      xml.ItemInventoryAssemblyLine do
        xml.ItemInventoryRef do
          xml.ListID      part_match.try(:sync_id)
        end
        xml.Quantity      part_variant.fetch(:quantity)
      end
    end

    # Return XML
    xml
  end

  def qbd_item_inventory_assembly_xml_to_variant(response, variant_hash)
    variant = self.company.variants_including_master.find_by_id(variant_hash.fetch(:id))
    by_name = self.integration_item.qbd_match_with_name
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemInventoryAssemblyQueryRs/ItemInventoryAssemblyRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemInventoryAssemblyRet", {})
    qbd_item_inventory_assembly_hash_to_variant(qbd_hash, variant.try(:product), variant)

    # sub_item = response.xpath("#{xpath_base}/ParentRef").try(:children).any?
    # {
    #   product: {
    #     name: sub_item ? nil : response.xpath("#{xpath_base}/Name").try(:children).try(:text),
    #     description: sub_item ? nil : response.xpath("#{xpath_base}/SalesDesc").try(:children).try(:text),
    #   }.compact,
    #   variant: {
    #     cost_price: response.xpath("#{xpath_base}/PurchaseCost").try(:children).try(:text),
    #   }.compact,
    #   price: response.xpath("#{xpath_base}/SalesPrice").try(:children).try(:text),
    #   sub_item: {
    #     name: sub_item ? response.xpath("#{xpath_base}/Name").try(:children).try(:text) : nil
    #   }.compact
    # }

    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_item_inventory_assembly?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemInventoryAssemblyQueryRs/ItemInventoryAssemblyRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemInventoryAssemblyRet", {})

    qbd_inventory_assembly_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_item_inventory_assembly_hash_to_variant(qbd_hash, product = nil, variant = nil)
    by_name = self.integration_item.qbd_match_with_name

    if product.nil?
      if qbd_hash.fetch('ParentRef', nil)
        parent_match = self.integration_item.integration_sync_matches.where(
          integration_syncable_type: "Spree::Variant",
          sync_type: "ItemInventoryAssembly",
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
    product.product_type = 'inventory_assembly'
    variant.variant_type = 'inventory_assembly'

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

    #TODO option_types/option_values

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

    qbd_inventory_assembly_find_or_assign_associated_opts(qbd_hash, variant, product)
    qbd_find_or_create_option_types_and_values(qbd_hash.fetch('FullName', ''), variant, product)
    product.save!
    variant.save!

    qbd_create_or_update_match(variant,
                              'Spree::Variant',
                              qbd_hash.fetch('ListID'),
                              'ItemInventoryAssembly',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
  end

  def qbd_inventory_assembly_find_or_assign_associated_opts(qbd_hash, variant = nil, product = nil)
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

    qbd_assign_parts(qbd_hash, 'ItemInventoryAssemblyLine', 'ItemInventoryRef', variant)

    if variant.present?
      variant.assign_account(income_account, 'income_account_id') if income_account
      variant.assign_account(cogs_account, 'cogs_account_id') if cogs_account
      variant.assign_account(asset_account, 'asset_account_id') if asset_account
      variant.txn_class_id = txn_class.try(:id)
    end

    product.assign_accounts_from_variant(variant) if product.present?
  end

  def qbd_item_inventory_assembly_to_csv(csv, item)
    part_lines = item.fetch('ItemInventoryAssemblyLine', [])
    if part_lines.is_a?(Array)
      if part_lines.empty?
        csv << [
          'ItemInventoryAssembly',
          item.fetch('FullName'),
          item.fetch('SalesDesc', nil),
          nil,
          nil
        ]
      end
      part_lines.each do |part_line|
        next if part_line.blank?
        csv << [
          'ItemInventoryAssembly',
          item.fetch('FullName'),
          item.fetch('SalesDesc', nil),
          part_line.fetch('ItemInventoryRef', {}).fetch('FullName', nil),
          part_line.fetch('Quantity', nil)
        ]
      end
    elsif part_lines.is_a?(Hash)
      csv << [
        'ItemInventoryAssembly',
        item.fetch('FullName'),
        item.fetch('SalesDesc', nil),
        part_lines.fetch('ItemInventoryRef', {}).fetch('FullName', nil),
        part_lines.fetch('Quantity', nil)
      ]
    end
  end

end
