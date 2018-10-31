FactoryGirl.define do
  factory :account_viewable_product, class: Spree::AccountViewableProduct do
    account
    product
    after(:create) do |avp|
      avp.product.reload.variants.each do |variant|
        avp.variants_prices[variant.id.to_s] = variant.price
        avp.save!
      end
    end
  end
end
