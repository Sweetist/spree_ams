class AddVendorToOptionTypes < ActiveRecord::Migration
  def up
    add_column :spree_option_types, :vendor_id, :integer
    add_index :spree_option_types, :vendor_id

    Spree::OptionValue.find_each do |ov|
      ot = Spree::OptionType.find_or_create_by(vendor_id: ov.vendor_id, name: ov.option_type.try(:name), presentation: ov.option_type.try(:presentation))
      ov.update_columns(option_type_id: ot.id)
      # each product only has one option type currently
      ov.variants.each {|v| v.product.option_type_ids = [ot.id]}
    end

    Spree::OptionType.where(vendor_id: nil).each do |ot|
      ot.destroy! unless ot.option_values.any?
    end
  end
  def down
    Spree::OptionValue.find_each do |ov|
      ot = Spree::OptionType.find_or_create_by(vendor_id: nil, name: ov.option_type.try(:name), presentation: ov.option_type.try(:presentation))
      ov.update_columns(option_type_id: ot.id)
      # each product only has one option type currently
      ov.variants.each {|v| v.product.option_type_ids = [ot.id]}
    end
    Spree::OptionType.where.not(vendor_id: nil).each do |ot|
      ot.destroy! unless ot.option_values.any?
    end

    remove_index :spree_option_types, :vendor_id
    remove_column :spree_option_types, :vendor_id, :integer
  end
end
