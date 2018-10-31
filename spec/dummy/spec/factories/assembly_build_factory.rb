FactoryGirl.define do
  factory :assembly_build, class: Spree::AssemblyBuild do
    assembly { build(:variant) }
    quantity 1
    factory :assembly_build_with_parts do
      after(:create) do |assembly_build|
        create(:assembly_build_part, assembly_build: assembly_build)
        create(:assembly_build_part, assembly_build: assembly_build)
      end
    end
  end
end
