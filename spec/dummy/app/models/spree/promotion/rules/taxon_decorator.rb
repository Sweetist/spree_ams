Spree::Promotion::Rules::Taxon.class_eval do
  def actionable?(line_item)
    taxon_product_ids.include?(line_item.variant.product_id) || taxon_variant_ids.include?(line_item.variant.id)
  end

  def match_item_taxons?(item)
    taxon_ids.any? { |taxon_id| item.taxons.any? { |taxon| taxon.id == taxon_id } }
  end

  private

  def order_taxons_in_taxons_and_children(order)
    (product_taxons(order).where(id: taxons_including_children_ids) +
      variant_taxons(order).where(id: taxons_including_children_ids)).distinct
  end

  def product_taxons(order)
    Spree::Taxon.joins(products: { variants_including_master: :line_items })
                .where(spree_line_items: { order_id: order.id }).uniq
  end

  def variant_taxons(order)
    Spree::Taxon.joins(variants: :line_items)
                .where(spree_line_items: { order_id: order.id }).uniq
  end

  def taxon_product_ids
    Spree::Product.joins(:taxons).where(spree_taxons: { id: taxons.pluck(:id) })
                  .pluck(:id).uniq
  end

  def taxon_variant_ids
    Spree::Variant.joins(:taxons).where(spree_taxons: { id: taxons.pluck(:id) })
                  .pluck(:id).uniq
  end
end
