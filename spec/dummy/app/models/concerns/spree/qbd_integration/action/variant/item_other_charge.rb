module Spree::QbdIntegration::Action::Variant::ItemOtherCharge

  def qbd_variant_to_item_other_charge_xml(xml, variant_hash, match = nil)
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
      parent_match = self.integration_item.integration_sync_matches.find_or_create_by(
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
    # if 'item_other_charge_sales_and_purchase'
    if variant_hash.fetch(:variant_type) == 'other_charge' && variant_hash.fetch(:product).fetch(:for_sale) && variant_hash.fetch(:product).fetch(:for_purchase)
      # SalesAndPurchase
      xml.send("SalesAndPurchase#{'Mod' if match}") do
        description = (self.integration_item.qbd_match_with_name ? variant_hash.fetch(:description) : variant_hash.fetch(:name))
        if description
          xml.SalesDesc    description.truncate(4095)
        end
        xml.SalesPrice   variant_hash.fetch(:price)
        if variant_hash.fetch(:income_account_id)
          xml.IncomeAccountRef do
            income_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:income_account_id), integration_syncable_type: 'Spree::ChartAccount')
            xml.ListID     income_account_match.try(:sync_id)
          end
        end
        if description
          xml.PurchaseDesc description.truncate(4095)
        end
        xml.PurchaseCost variant_hash.fetch(:cost_price)
        # if variant_hash.fetch(:tax_category_id)
        #   category_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:tax_category_id), integration_syncable_type: 'Spree::TaxCategory')
        #   xml.PurchaseTaxCodeRef do
        #     xml.ListID category_match.try(:sync_id)
        #   end
        # end
        if variant_hash.fetch(:expense_account_id)
          xml.ExpenseAccountRef do
            expense_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:expense_account_id), integration_syncable_type: 'Spree::ChartAccount')
            xml.ListID     expense_account_match.try(:sync_id)
          end
        end
      end
    elsif variant_hash.fetch(:variant_type) == 'other_charge'
      # SalesOrPurchase
      xml.send("SalesOrPurchase#{'Mod' if match}") do
        description = (self.integration_item.qbd_match_with_name ? variant_hash.fetch(:description) : variant_hash.fetch(:name))
        if description
          xml.Desc description.truncate(4095)
        end
        xml.Price variant_hash.fetch(:price)
        if variant_hash.fetch(:product).fetch(:for_sale) && variant_hash.fetch(:income_account_id)
          xml.AccountRef do
            income_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:income_account_id), integration_syncable_type: 'Spree::ChartAccount')
            xml.ListID     income_account_match.try(:sync_id)
          end
        elsif variant_hash.fetch(:product).fetch(:for_purchase) && variant_hash.fetch(:expense_account_id)
          xml.AccountRef do
            expense_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:expense_account_id), integration_syncable_type: 'Spree::ChartAccount')
            xml.ListID     expense_account_match.try(:sync_id)
          end
        end
      end
    end
    # Return XML
    xml
  end

  def qbd_item_other_charge_xml_to_variant(response, variant_hash)
    variant = self.company.variants_including_master.find_by_id(variant_hash.fetch(:id))
    by_name = self.integration_item.qbd_match_with_name
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemOtherChargeQueryRs/ItemOtherChargeRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemOtherChargeRet", {})
    qbd_item_other_charge_hash_to_variant(qbd_hash, variant.try(:product), variant)

    return {}
  end

  def qbd_all_associated_matched_item_other_charge?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemOtherChargeQueryRs/ItemOtherChargeRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemOtherChargeRet", {})

    qbd_non_inventory_item_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_item_other_charge_create_variant_sub_steps(qbd_hash)
    if qbd_hash.fetch('ParentRef', nil)
      parent_match = self.integration_item.integration_sync_matches.where(
        integration_syncable_type: "Spree::Variant",
        sync_type: "ItemOtherCharge",
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
    qbd_other_charge_find_or_assign_associated_opts(qbd_hash)
    if self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
      qbd_item_other_charge_hash_to_variant(qbd_hash)
    end
  end

  def qbd_item_other_charge_hash_to_variant(qbd_hash, product = nil, variant = nil)
    by_name = self.integration_item.qbd_match_with_name
    if product.nil?
      if qbd_hash.fetch('ParentRef', nil)
        parent_match = self.integration_item.integration_sync_matches.where(
          integration_syncable_type: "Spree::Variant",
          sync_type: "ItemOtherCharge",
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
    product.product_type = 'other_charge'
    variant.variant_type = 'other_charge'

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

    desc = qbd_other_charge_find_or_assign_associated_opts(qbd_hash, variant, product)
    if by_name
      product.name = qbd_hash.fetch('FullName', '').split(':').first
      product.description = desc if variant.is_master?
      variant.variant_description = desc
      variant.sku ||= qbd_hash.fetch('Name', '')
    else
      if variant.is_master?
        product.name = desc unless desc.blank?
        product.name = qbd_hash.fetch('Name', '') if desc.blank?
      end
      variant.sku = qbd_hash.fetch('Name', '')
    end

    qbd_find_or_create_option_types_and_values(qbd_hash.fetch('FullName', ''), variant, product)

    product.save!
    variant.save!

    qbd_create_or_update_match(variant,
                              'Spree::Variant',
                              qbd_hash.fetch('ListID'),
                              'ItemOtherCharge',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
  end

  def qbd_other_charge_find_or_assign_associated_opts(qbd_hash, variant = nil, product = nil)
    if qbd_hash.fetch('SalesOrPurchase', nil)
      sop = qbd_hash.fetch('SalesOrPurchase', {})
      desc = sop.fetch('Desc', '')

      acc = nil
      if sop.fetch('AccountRef', nil)
        acc = qbd_find_chart_account_by_id_or_name(sop, 'AccountRef')
      end
      if variant && product
        if sop.fetch('Price', nil)
          variant.price = sop.fetch('Price', 0)
        elsif sop.fetch('PricePercent', nil)
          raise "PricePercent is not supported"
        end

        if acc.present?
          if acc.chart_account_category.try(:name) == 'Income Account'
            variant.assign_account(acc, 'income_account_id')
            product.for_sale = true
            product.for_purchase = false
          else
            variant.cost_price = sop.fetch('Price', nil) || 0
            variant.assign_account(acc, 'expense_account_id')
            product.for_sale = false
            product.for_purchase = true
          end
        end
      end
    else
      sap = qbd_hash.fetch('SalesAndPurchase', {})

      if sap.fetch('IncomeAccountRef', nil)
        income_acc = qbd_find_chart_account_by_id_or_name(sap, 'IncomeAccountRef')
      end

      if sap.fetch('ExpenseAccountRef', nil)
        expense_acc = qbd_find_chart_account_by_id_or_name(sap, 'ExpenseAccountRef')
      end
      desc = sap.fetch('SalesDesc', '')
      desc = sap.fetch('PurchaseDesc', '') if desc.blank?

      if variant && product
        price = sap.fetch('SalesPrice', 0)
        cost_price = sap.fetch('PurchaseCost', nil)
        variant.price = price unless price.nil?
        variant.cost_price = cost_price unless cost_price.nil?
        product.for_sale = true
        product.for_purchase = true

        variant.assign_account(expense_acc, 'expense_account_id') if expense_acc
        variant.assign_account(income_acc, 'income_account_id') if income_acc
      end
    end

    txn_class = qbd_find_transaction_class_by_id_or_name(qbd_hash, 'ClassRef')
    if variant && product
      product.assign_accounts_from_variant(variant)
      variant.txn_class_id = txn_class.try(:id)
    end

    desc
  end

  def qbd_item_other_charge_to_csv(csv, item)
    if item.fetch('SalesOrPurchase', nil).present?
      desc = item.fetch('SalesOrPurchase').fetch('Desc', nil)
    else
      desc = item.fetch('SalesAndPurchase').fetch('SalesDesc', nil)
    end
    csv << [
      'ItemOtherCharge',
      item.fetch('FullName'),
      desc,
      nil, # space saver for part FullName
      nil  # space saver for part QTY
    ]
  end

end
