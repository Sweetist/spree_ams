module Spree
  class AssemblyBuild < Spree::Base
    belongs_to :assembly, foreign_key: :assembly_id, class_name: 'Spree::Variant'
    has_many :build_parts, class_name: 'Spree::AssemblyBuildPart',
                           foreign_key: :build_id, primary_key: :id
  end
end
