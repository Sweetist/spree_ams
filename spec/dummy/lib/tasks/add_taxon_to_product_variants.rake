desc 'Add taxon to product variants'
task add_taxon_to_product_varaints: :environment do
  FillProductVariantsClassification.call
end
