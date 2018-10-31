FactoryGirl.define do
  factory :vendor_import, class: Spree::VendorImport do
    company { |c| Spree::Company.first || c.association(:company) }
    delimer ","
    encoding "ISO-8859-2"
    replace false
    proceed false
    proceed_verified false
  end
end
