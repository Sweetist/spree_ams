# == Schema Information
#
# Table name: spree_assembly_build_parts
#
#  id                :integer          not null, primary key
#  build_id          :integer
#  quantity          :integer
#  variant_id        :integer
#  stock_item_lot_id :integer
#  stock_location_id :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

FactoryGirl.define do
  factory :spree_assembly_build_part, :class => 'Spree::AssemblyBuildPart' do
    build_id 1
quantity 1
variant_id 1
stock_item_lot_id 1
stock_location_id "MyString"
integer "MyString"
  end

end
