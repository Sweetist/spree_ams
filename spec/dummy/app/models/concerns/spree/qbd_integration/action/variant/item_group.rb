module Spree::QbdIntegration::Action::Variant::ItemGroup

  def qbd_variant_to_item_group_xml(xml, variant_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           (self.integration_item.qbd_match_with_name ? variant_hash.fetch(:name) : variant_hash.fetch(:sku)).to_s #CHAR LIMIT 31
    xml.IsActive       variant_hash.fetch(:active, true)
    description = (self.integration_item.qbd_match_with_name ? variant_hash.fetch(:description) : variant_hash.fetch(:name))
    if description
      xml.ItemDesc        description.truncate(4095)
    end
    variant_hash.fetch(:parts_variants, []).each do |part_variant|
      part_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: part_variant.fetch(:part_id), integration_syncable_type: 'Spree::Variant')
      xml.ItemGroupLine do
        xml.ItemRef do
          xml.ListID      part_match.try(:sync_id)
        end
        xml.Quantity      part_variant.fetch(:quantity)
      end
    end

    # Return XML
    xml
  end

  def qbd_item_group_xml_to_variant(response, variant_hash)
    variant = self.company.variants_including_master.find_by_id(variant_hash.fetch(:id))
    by_name = self.integration_item.qbd_match_with_name
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemGroupQueryRs/ItemGroupRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemGroupRet", {})
    qbd_item_group_hash_to_variant(qbd_hash, variant.try(:product), variant)

    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_item_group?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemGroupQueryRs/ItemGroupRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemGroupRet", {})

    qbd_bundle_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_item_group_hash_to_variant(qbd_hash, product = nil, variant = nil)
    by_name = self.integration_item.qbd_match_with_name

    if product.nil?

      if by_name
        product ||= self.company.products.find_by_name(qbd_hash.fetch('Name', ''))
      else
        product ||= self.company.variants_including_master.where(
                  sku: qbd_hash.fetch('Name', ''),
                  is_master: true
                ).first.try(:product)
      end
      product ||= self.integration_item.company.products.new
      variant = product.master
    end


    date = qbd_hash.fetch('TimeCreated').to_date
    product.available_on ||= date
    product.shipping_category_id ||= self.integration_item.qbd_default_shipping_category_id
    product.product_type = 'bundle'
    variant.variant_type = 'bundle'

    desc = qbd_hash.fetch('ItemDesc', nil)

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

    if by_name
      product.name = qbd_hash.fetch('Name', '')
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

    product.for_sale = true
    product.for_purchase = false

    qbd_assign_parts(qbd_hash, 'ItemGroupLine', 'ItemRef', variant)

    prices = Hash.new(0)
    variant.price = variant.parts_variants.includes(:part).each do |part_variant|
      sale_price = (part_variant.part.try(:price) || 0).to_d
      cost_price = (part_variant.part.try(:cost_price) || 0).to_d
      prices[:sale] += sale_price * part_variant.count.to_f
      prices[:cost] += cost_price * part_variant.count.to_f
    end
    variant.price = prices[:sale]
    variant.cost_price = prices[:cost]

    product.save!
    variant.save!

    qbd_create_or_update_match(variant,
                              'Spree::Variant',
                              qbd_hash.fetch('ListID'),
                              'ItemGroup',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
  end

  def qbd_bundle_find_or_assign_associated_opts(qbd_hash)
    # add methods here to find or create steps for associated objects like
    # chart of accounts if necessary
  end

  def qbd_item_group_to_csv(csv, item)
    part_lines = item.fetch('ItemGroupLine', [])
    if part_lines.is_a?(Array)
      if part_lines.empty?
        csv << [
          'ItemGroup',
          item.fetch('Name'),
          item.fetch('ItemDesc', nil),
          nil,
          nil
        ]
      end
      item.fetch('ItemGroupLine', []).each do |part_line|
        next if part_line.blank?
        csv << [
          'ItemGroup',
          item.fetch('Name'),
          item.fetch('ItemDesc', nil),
          part_line.fetch('ItemRef', {}).fetch('FullName', nil),
          part_line.fetch('Quantity', nil)
        ]
      end
    elsif part_lines.is_a?(Hash)
      csv << [
        'ItemGroup',
        item.fetch('Name'),
        item.fetch('ItemDesc', nil),
        part_lines.fetch('ItemRef', {}).fetch('FullName', nil),
        part_lines.fetch('Quantity', nil)
      ]
    end


  end

end
