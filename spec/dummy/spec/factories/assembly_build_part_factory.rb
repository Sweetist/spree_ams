FactoryGirl.define do
  factory :assembly_build_part, class: Spree::AssemblyBuildPart do
    assembly_build(:assembly_build)
    variant { build(:variant) }
    quantity 1
    stock_item_lot do
      stock_location = create(:stock_location)
      variant = create(:variant)
      stock_item = variant.stock_items.find_by(stock_location: stock_location)
      create(:stock_item_lot, stock_item: stock_item, variant: variant)
    end
  end
end
