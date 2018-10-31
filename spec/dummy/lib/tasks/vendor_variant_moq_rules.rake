desc 'Create variant order rules for vendors'
task create_variant_moq_rules: :environment do
  MigrateFromDeliveryMinimum.call
end
