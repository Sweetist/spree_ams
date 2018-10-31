# == Schema Information
#
# Table name: spree_product_imports
#
#  id                :integer          not null, primary key
#  file_file_name    :string
#  file_content_type :string
#  file_file_size    :integer
#  file_updated_at   :datetime
#  encoding          :string
#  delimer           :string
#  replace           :boolean
#  status            :integer
#  verify_result     :json
#  import_result     :json
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  proceed           :boolean
#  proceed_verified  :boolean
#  exception_message :text
#  vendor_id         :integer
#

class Spree::ProductImport < ActiveRecord::Base
  include Spree::Importable
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  alias_attribute :company, :vendor

  has_attached_file :file
  validates :file, presence: true
  validates_attachment_content_type :file, content_type: ["text/plain", "text/csv", "application/vnd.ms-excel"]
  validates_attachment_file_name :file, matches: [/csv\z/]


  attr_default :status, 0
  attr_default :proceed, false
  attr_default :proceed_verified, false

  def import!
    self.update_columns(status: 5)
    self.import_result = self.verify_result.map do |hash_product|
      product_data = hash_product.fetch('product',{})
      master = self.vendor.variants_including_master.where(sku: product_data.fetch('master_attributes').fetch('sku'), is_master: true).first
      product = master.try(:product)

      if self.replace && product.present?
        variants = []
        master.assign_attributes(product_data.fetch('master_attributes'))
        unless master.save
          hash_product['errors'] += master.errors.full_messages
        end
        product.assign_attributes(product_data.dup.delete_if{|k,v| k.include?('attributes')})
        product_data.fetch('variants_attributes', []).each do |var_attr|
          variant = product.variants.where(sku: var_attr.fetch('sku')).first
          if variant.present?
            variant.assign_attributes(var_attr)
            unless variant.save
              hash_product['errors'] += variant.errors.full_messages
            end
          else
            variants << product.variants.new(var_attr)
          end
        end
      else
        product = Spree::Product.new(product_data)
      end

      product.product_option_types.each do |pot|
        pot.position = product_data.fetch('option_type_ids',[]).find_index(pot.option_type_id).to_i + 1
      end

      # TODO find or replace images
      if hash_product.fetch('valid', false) && product.save
        images = product_data.fetch('import_images', []).map do |image_url|
          product.images.create(attachment: URI.parse(image_url), alt: product.slug)
        end
        {
          product: product_data,
          images: images,
          imported: hash_product.fetch('errors').empty?,
          errors: hash_product.fetch('errors')
        }
      else
        {
          product: product_data,
          images: [],
          imported: false,
          errors: hash_product.fetch('errors')
        }
      end
    end
    self.status = 6
    self.save
    Spree::ImportMailer.products_import(self.id).deliver_now
  rescue Exception => e
    self.status = 10
    self.exception_message = e.message
    self.save
  end


  def verify!
    self.update_columns(status: 1)
    products = []
    path = Paperclip.io_adapters.for(self.file).path
    hash_product = {}
    SmarterCSV.process(path, {chunk_size: 100, col_sep: self.delimer, row_sep: :auto, file_encoding: self.encoding}) do |chunk|
      chunk.each do |csv_product|
        next unless csv_product.values.any?{|value| value.present?}
        if csv_product[:"*name*"]
          products << self.validate_product(hash_product) unless hash_product.empty?
          hash_product = self.csv_to_product(csv_product)
        else
          hash_product['product']['variants_attributes'] << self.csv_to_variant(csv_product, hash_product) #rescue raise "Unable to match products. Please verify that your import file contains the appropriate column names in the first row."
        end
      end
    end
    products << self.validate_product(hash_product)
    self.verify_result = products

    if self.verify_result.count == 0 || (self.verify_result.count > 0 && self.verify_result.select{|x| x['valid'] == false}.count > 0)
      self.status = 3
    else
      self.status = 2
    end
    self.save
    Spree::ImportMailer.products_verify(self.id).deliver_now
    if (self.status == 2 and self.proceed) or (self.status == 3 and self.proceed_verified)
      self.import!
    end
  rescue Exception => e
    self.status = 10
    self.exception_message = e.message
    self.save
  end

  protected

  def validate_product(hash_product)
    product_data = hash_product.fetch('product',{})
    master = self.vendor.variants_including_master.where(sku: product_data.fetch('master_attributes').fetch('sku'), is_master: true).first
    product = master.try(:product)

    if self.replace && product.present?
      variants = []
      master.assign_attributes(product_data.fetch('master_attributes'))
      product.assign_attributes(product_data.dup.delete_if{|k,v| k.include?('attributes')})
      product_data.fetch('variants_attributes', []).each do |var_attr|
        variant = product.variants.where(sku: var_attr.fetch('sku')).first
        if variant.present?
          variant.assign_attributes(var_attr)
        else
          variants << product.variants.new(var_attr)
        end
      end
    else
      product = Spree::Product.new(product_data)
    end

    begin
      unless product.valid?
        hash_product['valid'] = false if hash_product['valid']
        product.errors.full_messages.each do |error_message|
          hash_product['errors'] << error_message
        end
      end
    rescue Exception => e
      hash_product['valid'] = false if hash_product['valid']
      hash_product['errors'] << e.message
    end
    hash_product
  end

  def csv_to_product(csv_product)
    valid = true
    errors = []

    shipping = self.vendor.shipping_categories.where("spree_shipping_categories.name ILIKE ?", csv_product[:'*shipping_category*'].to_s).first || self.vendor.shipping_categories.create(name: csv_product[:'*shipping_category*'].to_s)
    unless shipping
      valid = false
      errors << "Shipping category \"#{csv_product[:'*shipping_category*']}\" was not recognized"
    end
    tax = self.vendor.tax_categories.where("name ILIKE ?", csv_product[:'*tax_category*'].to_s).first
    tax ||= self.vendor.tax_categories.where('tax_code ILIKE ?', csv_product[:'*tax_category*'].to_s).first
    tax ||= self.vendor.tax_categories.create(name: csv_product[:'*tax_category*'], tax_code: csv_product[:'*tax_category*'])
    unless tax.try(:persisted?)
      valid = false
      message = "Tax category \"#{csv_product[:'*tax_category*']}\" was not found."
      if tax.errors.full_messages.any?
        message += " Failed to create new tax category: #{tax.errors.full_messages}"
      end
      errors << message
    end
    option_types = []
    option_type_ids = []
    Sweet::Application.config.x.max_option_types.times do |idx|
      n = idx + 1
      ot_key = "option_type_#{n}".to_sym
      if csv_product[ot_key]
        option_types[idx] = self.vendor.option_types.where('name ILIKE ?', csv_product[ot_key].to_s).first
        option_types[idx] ||= self.vendor.option_types.create(name: csv_product[ot_key].to_s, presentation: csv_product[ot_key].to_s)

        if option_types[idx].try(:id)
          option_type_ids << option_types[idx].id
        else
          valid = false
          errors << "Option Type \"#{csv_product[ot_key]}\" was not recognized"
        end
      end
    end

    product_type = nil
    if csv_product[:product_type].present?
      begin
        product_type = csv_product[:product_type].underscore.gsub(' ','_')
        raise unless PRODUCT_TYPES[product_type]
      rescue
        valid = false
        errors << "Product Type must be one of [#{PRODUCT_TYPES.values.join(', ')}]"
      end
    end
    weight_units = nil
    if csv_product[:'weight_units(oz/lb/gm/kg)'].present?
      begin
        weight_units = csv_product[:'weight_units(oz/lb/gm/kg)'].to_s.downcase
        raise unless Sweet::Application.config.x.weight_units.to_h[weight_units]
      rescue
        valid = false
        errors << "Invalid weight unit (#{csv_product[:'weight_units(oz/lb/gm/kg)']}). Must be in the list: #{Sweet::Application.config.x.weight_units.to_h.keys.join(', ')}"
      end
    end
    dimension_units = nil
    if csv_product[:'dimension_units(cm/in)'].present?
      begin
        dimension_units = csv_product[:'dimension_units(cm/in)'].to_s.downcase
        raise unless Sweet::Application.config.x.dimension_units.to_h[dimension_units]
      rescue
        valid = false
        errors << "Invalid dimension unit (#{csv_product[:'dimension_units(cm/in)']}). Must be in the list: #{Sweet::Application.config.x.dimension_units.to_h.keys.join(', ')}"
      end
    end

    income_account = nil
    if csv_product[:income_account].present?
      income_account = find_or_create_chart_account(
        csv_product[:income_account],
        Spree::ChartAccountCategory.find_by_name('Income Account').id
      )
    end

    expense_account = nil
    if csv_product[:expense_account].present?
      expense_account = find_or_create_chart_account(
        csv_product[:expense_account],
        Spree::ChartAccountCategory.find_by_name('Expense Account').id
      )
    end

    cogs_account = nil
    if csv_product[:cogs_account].present?
      cogs_account = find_or_create_chart_account(
        csv_product[:cogs_account],
        Spree::ChartAccountCategory.find_by_name('Cost of Goods Sold Account').id
      )
    end

    asset_account = nil
    if csv_product[:asset_account].present?
      asset_account = find_or_create_chart_account(
        csv_product[:asset_account],
        Spree::ChartAccountCategory.find_by_name('Asset Account').id
      )
    end

    available_on = nil
    begin
      raise unless csv_product[:'*available_on_(mm/dd/yyyy)*'].to_s.match(/(\d{1,2}\/\d{1,2}\/\d{2,4})/)
      if csv_product[:'*available_on_(mm/dd/yyyy)*'].to_s.match(/(\d{1,2}\/\d{1,2}\/\d{4})/)
        available_on = Date.strptime(csv_product[:'*available_on_(mm/dd/yyyy)*'].to_s, "%m/%d/%Y")
      else
        available_on = Date.strptime(csv_product[:'*available_on_(mm/dd/yyyy)*'].to_s, "%m/%d/%y")
      end
    rescue
      valid = false
      errors << "Available On is in invalid format (#{csv_product[:'*available_on_(mm/dd/yyyy)*']}). Please use MM/DD/YYYY."
    end
    cost_price = nil
    csv_product[:cost_price] = csv_product[:cost_price].to_s.gsub(/[^0-9.]/, '')
    unless csv_product[:cost_price].to_s.match(/^\d+(\.\d{1,2})?$/).nil?
      cost_price = csv_product[:cost_price].to_f
    end
    price = nil
    csv_product[:'*price*'] = csv_product[:'*price*'].to_s.gsub(/[^0-9.]/, '')
    unless csv_product[:'*price*'].to_s.match(/^\d+(\.\d{1,2})?$/).nil?
      price = csv_product[:'*price*'].to_f
    end
    for_sale = true
    if csv_product[:for_sale].present?
      for_sale = %w[yes y true t on].include?(csv_product[:for_sale].downcase)
    end
    for_purchase = false
    if csv_product[:for_purchase].present?
      for_purchase = %w[yes y true t on].include?(csv_product[:for_purchase].downcase)
    end
    can_be_part = false
    if csv_product[:can_be_part].present?
      begin
        can_be_part = %w[yes y true t on].include?(csv_product[:can_be_part].downcase)
        raise if BUILD_TYPES.keys.include?(product_type) && can_be_part
      rescue
        valid = false
        errors << "#{product_type.to_s.titleize} can't be a part"
      end
    end

    {
      'product' => {
        'name' => csv_product[:"*name*"],
        'display_name' => csv_product[:display_name].to_s,
        'description' => csv_product[:description],
        'slug' => csv_product[:slug],
        'meta_description' => csv_product[:meta_description],
        'meta_keywords' => csv_product[:meta_keyword],
        'meta_title' => csv_product[:meta_title],
        'available_on' => available_on,
        'price' => price,
        'vendor_id' => self.vendor_id,
        'shipping_category_id' => shipping.try(:id),
        'tax_category_id' => tax.try(:id),
        'product_type' => product_type,
        'income_account_id' => income_account.try(:id),
        'expense_account_id' => expense_account.try(:id),
        'cogs_account_id' => cogs_account.try(:id),
        'asset_account_id' => asset_account.try(:id),
        'for_sale' => for_sale,
        'for_purchase' => for_purchase,
        'can_be_part' => can_be_part,
        'promotionable' => true, #make all products promotionable
        'master_attributes' => {
          'is_master' => true,
          'display_name' => csv_product[:display_name].to_s,
          'sku' => csv_product[:'*sku*'],
          'cost_price' => cost_price,
          'price' => price,
          'weight' => csv_product[:weight],
          'height' => csv_product[:height],
          'width' => csv_product[:width],
          'depth' => csv_product[:depth],
          'cost_currency' => csv_product[:cost_currency],
          'lead_time' => csv_product[:'*lead_time_(days)*'],
          'pack_size' => csv_product[:pack_size].to_s,
          'weight_units' => weight_units,
          'dimension_units' => dimension_units,
          'variant_type' => product_type,
          'track_inventory' => INVENTORY_TYPES.has_key?(product_type)
        },
        'variants_attributes' => [],
        'option_type_ids' => option_type_ids,
        'import_images' => csv_product[:images].to_s.split(";"),
        'taxon_ids' => csv_product[:categories].to_s.split('|').map do |taxons_string|
          taxonomy = Spree::Taxonomy.where(vendor_id: self.vendor_id).first
          taxonomy ||= self.vendor.taxonomies.create(name: self.vendor.name)
          last = taxonomy.try(:root)
          taxon_name = ""
          taxons_string.to_s.split(">").map(&:strip).each do |taxon_string|
            taxon_name = taxon_string
            next if taxon_name.blank?
            parent_id = last.try(:id)
            last = self.vendor.taxons.where('name ILIKE ?', taxon_name.to_s).where(parent_id: parent_id).first
            if last.nil?
              last = self.vendor.taxons.new(name: taxon_name, parent_id: parent_id, taxonomy_id: taxonomy.try(:id))
              unless last.save
                valid = false if valid
                errors << last.errors.full_messages
              end
            end
          end
          unless last
            valid = false if valid
            errors << "Category Name \"#{taxon_name.capitalize}\" was not recognized"
          end
          last.try(:id)
        end.compact
      },
      'valid' => valid,
      'errors' => errors
    }
  end

  def csv_to_variant(csv_product, hash_product)
    option_values = []
    option_value_ids = []
    product_data = hash_product.fetch('product',{})
    Sweet::Application.config.x.max_option_types.times do |idx|
      n = idx + 1
      ov_key = "option_value_#{n}".to_sym
      if csv_product[ov_key].present?
        ov_name = csv_product[ov_key]
        option_values[idx] = self.vendor.option_values.where('presentation ILIKE ? AND option_type_id = ?', csv_product[ov_key], product_data.fetch("option_type_ids",[])[idx]).first
        option_values[idx] ||= self.vendor.option_values.where('name ILIKE ? AND option_type_id = ?', csv_product[ov_key], product_data.fetch("option_type_ids",[])[idx]).first
        option_values[idx] ||= self.vendor.option_values.create(name: csv_product[ov_key], presentation: csv_product[ov_key], option_type_id: product_data.fetch("option_type_ids",[])[idx])
        if option_values[idx].try(:id)
          option_value_ids << option_values[idx].id
        else
          hash_product['valid'] = false if hash_product['valid']
          hash_product['errors'] << "Option Value \"#{csv_product[ov_key]}\" was not recognized"
        end
      end
    end
    cost_price = 0
    csv_product[:cost_price] = csv_product[:cost_price].to_s.gsub(/[^0-9.]/, '')
    unless csv_product[:cost_price].to_s.match(/^\d+(\.\d{1,2})?$/).nil?
      cost_price = csv_product[:cost_price].to_f
    end
    price = 0
    csv_product[:'*price*'] = csv_product[:'*price*'].to_s.gsub(/[^0-9.]/, '')
    unless csv_product[:'*price*'].to_s.match(/^\d+(\.\d{1,2})?$/).nil?
      price = csv_product[:'*price*'].to_f
    end

    weight_units = nil
    if csv_product[:'weight_units(oz/lb/gm/kg)'].present?
      begin
        weight_units = csv_product[:'weight_units(oz/lb/gm/kg)'].to_s.downcase
        raise unless Sweet::Application.config.x.weight_units.to_h[weight_units]
      rescue
        hash_product['valid'] = false
        hash_product['errors'] << "Invalid weight unit (#{csv_product[:'weight_units(oz/lb/gm/kg)']}). Must be in the list: #{Sweet::Application.config.x.weight_units.to_h.keys.join(', ')}"
      end
    end

    dimension_units = nil
    if csv_product[:'dimension_units(cm/in)'].present?
      begin
        dimension_units = csv_product[:'dimension_units(cm/in)'].to_s.downcase
        raise unless Sweet::Application.config.x.dimension_units.to_h[dimension_units]
      rescue
        hash_product['valid'] = false
        hash_product['errors']<< "Invalid dimension unit (#{csv_product[:'dimension_units(cm/in)']}). Must be in the list: #{Sweet::Application.config.x.dimension_units.to_h.keys.join(', ')}"
      end
    end

    variant_taxon_ids = csv_product[:categories].to_s.split('|').map do |taxons_string|
      taxonomy = Spree::Taxonomy.where(vendor_id: self.vendor_id).first
      taxonomy ||= self.vendor.taxonomies.create(name: self.vendor.name)
      last = taxonomy.try(:root)
      taxon_name = ""
      taxons_string.to_s.split(">").map(&:strip).each do |taxon_string|
        taxon_name = taxon_string
        next if taxon_name.blank?
        parent_id = last.try(:id)
        last = self.vendor.taxons.where('name ILIKE ?', taxon_name.to_s).where(parent_id: parent_id).first
        if last.nil?
          last = self.vendor.taxons.new(name: taxon_name, parent_id: parent_id, taxonomy_id: taxonomy.try(:id))
          unless last.save
            valid = false if valid
            errors << last.errors.full_messages
          end
        end
      end
      unless last
        valid = false if valid
        errors << "Category Name \"#{taxon_name.capitalize}\" was not recognized"
      end
      last.try(:id)
    end.compact

    {
      'is_master' => false,
      'display_name' => csv_product[:display_name].to_s,
      'variant_description' => csv_product[:description],
      'sku' => csv_product[:'*sku*'],
      'cost_price' => cost_price,
      'price' => price,
      'weight' => csv_product[:weight],
      'height' => csv_product[:height],
      'width' => csv_product[:width],
      'depth' => csv_product[:depth],
      'cost_currency' => csv_product[:cost_currency],
      'lead_time' => csv_product[:'*lead_time_(days)*'],
      'pack_size' => csv_product[:pack_size].to_s,
      'weight_units' => weight_units,
      'dimension_units' => dimension_units,
      'option_value_ids' => option_value_ids,
      'track_inventory' => false,
      'taxon_ids' => variant_taxon_ids
    }
  end

  def find_or_create_chart_account(full_name, chart_account_category_id)
    parent_name = ''
    name_parts = full_name.to_s.split(':')
    parent_account = nil
    chart_account = nil
    name_parts.each_with_index do |name, idx|
      if parent_account.present?
        chart_account = parent_account.child_accounts.find_or_initialize_by(
          name: name,
          chart_account_category_id: chart_account_category_id,
          vendor_id: self.vendor_id
        )
      else
        chart_account = self.vendor.chart_accounts.find_or_initialize_by(
          name: name,
          chart_account_category_id: chart_account_category_id,
          parent_id: nil
        )
      end
      chart_account.save
      parent_account = chart_account
    end

    chart_account
  end
end
