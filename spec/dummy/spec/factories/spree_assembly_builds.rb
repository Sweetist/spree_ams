# == Schema Information
#
# Table name: spree_assembly_builds
#
#  id          :integer          not null, primary key
#  assembly_id :integer          not null
#  quantity    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

FactoryGirl.define do
  factory :spree_assembly_build, :class => 'Spree::AssemblyBuild' do
    assembly_id 1
quantity 1
  end

end
