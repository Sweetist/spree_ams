# Add classification to variants in product with taxons
class FillProductVariantsClassification
  def self.call
    Spree::Product.find_each do |product|
      next unless product.taxons.present?
      product.taxons.each do |taxon|
        product.variants_including_master.each do |variant|
          Spree::Classification.find_or_create_by(product_id: product.id,
                                                  taxon_id: taxon.id,
                                                  variant_id: variant.id)
        end
      end
    end
  end
end
