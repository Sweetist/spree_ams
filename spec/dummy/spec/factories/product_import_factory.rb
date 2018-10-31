FactoryGirl.define do
  factory :product_import, class: Spree::ProductImport do
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    delimer ","
    encoding "ISO-8859-2"
    replace false
    proceed false
    proceed_verified false
  end
end
