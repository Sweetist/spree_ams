module Spree::CustomerViewableAttribute::PageSettings
  extend ActiveSupport::Concern
  included do
    PAGE_DEFAULTS = {
      'catalog' => {
        'logo' => {
          'hide' => false,
        },
        'banner_text' => {
          'content' => 'CATALOG',
          'style' => {
            'font-size' => '45px',
            'color' => '#FFFFFF',
            'text-align' => 'left',
            'opacity' => '0.6',
            'top' => '40%'
          }
        },
        'categories' => true,
        'account_name_and_number' => true,
        'search_bar' => true,
        'add_to_cart' => 'modals',
        'after_add_to_cart' => 'products',
        'products_per_page' => 25,
        'show_images' => true,
        'stock_level' => {
          'show' => false,
          'sum' => false,
          'in_stock_text' => ''
        }
      },
      'product' => {
        'prev_next' => {
          'show' => true
        },
        'similar_products' => true
      },
      'logo' => {
        'size' => 'medium',
        'alignment' => 'left'
      },
      'footer' => {
        'powered_by_sweet' => true
      },
      'order_success' => {
        'text' => ''
      },
      'default_sorts' => {
        'variant' => ['full_display_name asc'],
        'line_item' => ['position asc']
      }

    }.freeze

    attr_default :pages do
      PAGE_DEFAULTS
    end

    PAGE_DEFAULTS.keys.each do |key|
      define_method "pages_#{key}" do
        (pages[key].nil? ? PAGE_DEFAULTS[key] : pages[key]) || {}
      end
      define_method "pages_#{key}=" do |value|
        default = PAGE_DEFAULTS[key]
        pages[key] = value.to_hash if default.is_a?(Hash)
        pages[key] = value.to_s if default.is_a?(String)
        pages[key] = value.to_i if default.is_a?(Integer)
        pages[key] = value.to_bool if default.is_a?(BooleanToBoolean)
      end
    end
  end

  def hide_logo(page)
    self.method("pages_#{page}").call.fetch('logo', {}).fetch('hide', false) rescue false
  end

  def catalog_show_logo
    !hide_logo('catalog')
  end
  def catalog_show_logo=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['logo'] ||= {}
    self.pages['catalog']['logo']['hide'] = !value.to_bool
  end

  def logo_size
    self.pages.fetch('logo', {}).fetch('size', 'medium') rescue nil
  end
  def logo_size=(value)
    self.pages ||= {}
    self.pages['logo'] ||= {}
    self.pages['logo']['size'] = value
  end

  def logo_alignment
    self.pages.fetch('logo', {}).fetch('alignment', 'left') rescue nil
  end
  def logo_alignment=(value)
    self.pages ||= {}
    self.pages['logo'] ||= {}
    self.pages['logo']['alignment'] = value
  end

  def footer_powered_by_sweet
    self.pages.fetch('footer', {}).fetch('powered_by_sweet', true) rescue true
  end
  def footer_powered_by_sweet=(value)
    self.pages ||= {}
    self.pages['footer'] ||= {}
    self.pages['footer']['powered_by_sweet'] = value.to_bool
  end

  def inline_banner_text_style
    self.pages_catalog.fetch('banner_text', {}).fetch('style',{}).map do |k, v|
      "#{k}:#{v};"
    end.join(" ")
  end

  def banner_text_color
    self.pages.fetch('catalog', {}).fetch('banner_text', {}).fetch('style',{}).fetch('color', nil) rescue nil
  end
  def banner_text_color=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['banner_text'] ||= {}
    self.pages['catalog']['banner_text']['style'] ||= {}
    self.pages['catalog']['banner_text']['style']['color'] = value.to_s
  end

  def banner_text_content
    self.pages.fetch('catalog', {}).fetch('banner_text', {}).fetch('content','') rescue ''
  end
  def banner_text_content=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['banner_text'] ||= {}
    self.pages['catalog']['banner_text']['content'] = value.to_s
  end

  def banner_text_font_size
    self.pages.fetch('catalog', {}).fetch('banner_text', {}).fetch('style',{}).fetch('font-size', nil).gsub(/\D/, '') rescue nil
  end
  def banner_text_font_size=(value)
    value = value.to_s.gsub(/\D/, '')
    value = '0' if value.length == 0
    value += 'px'
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['banner_text'] ||= {}
    self.pages['catalog']['banner_text']['style'] ||= {}
    self.pages['catalog']['banner_text']['style']['font-size'] = value
  end

  def banner_text_alignment
    self.pages.fetch('catalog', {}).fetch('banner_text', {}).fetch('style',{}).fetch('text-align', nil) rescue nil
  end
  def banner_text_alignment=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['banner_text'] ||= {}
    self.pages['catalog']['banner_text']['style'] ||= {}
    self.pages['catalog']['banner_text']['style']['text-align'] = value.to_s
  end

  def banner_text_vertical
    self.pages.fetch('catalog', {}).fetch('banner_text', {}).fetch('style',{}).fetch('top', nil) rescue nil
  end
  def banner_text_vertical=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['banner_text'] ||= {}
    self.pages['catalog']['banner_text']['style'] ||= {}
    self.pages['catalog']['banner_text']['style']['top'] = value.to_s
  end

  def banner_text_opacity
    self.pages.fetch('catalog', {}).fetch('banner_text', {}).fetch('style',{}).fetch('opacity', '1.0') rescue nil
  end
  def banner_text_opacity=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['banner_text'] ||= {}
    self.pages['catalog']['banner_text']['style'] ||= {}
    self.pages['catalog']['banner_text']['style']['opacity'] = value.to_s
  end

  def catalog_categories
    self.pages.fetch('catalog', {}).fetch('categories', true) rescue true
  end
  def catalog_categories=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['categories'] = value.to_bool
  end
  def catalog_search_bar
    self.pages.fetch('catalog', {}).fetch('search_bar', true) rescue true
  end
  def catalog_search_bar=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['search_bar'] = value.to_bool
  end
  def catalog_add_to_cart
    self.pages.fetch('catalog', {}).fetch('add_to_cart', PAGE_DEFAULTS.fetch('catalog').fetch('add_to_cart')) rescue 'modals'
  end
  def catalog_add_to_cart=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['add_to_cart'] = value unless value.blank?
  end
  def catalog_after_add_to_cart
    self.pages.fetch('catalog', {}).fetch('after_add_to_cart', PAGE_DEFAULTS.fetch('catalog').fetch('after_add_to_cart')) rescue 'products'
  end
  def catalog_after_add_to_cart=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['after_add_to_cart'] = value unless value.blank?
  end
  def catalog_products_per_page
    self.pages.fetch('catalog', {}).fetch('products_per_page', PAGE_DEFAULTS.fetch('catalog').fetch('products_per_page')) rescue 25
  end
  def catalog_products_per_page=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['products_per_page'] = value.to_i
  end
  def catalog_show_images
    self.pages.fetch('catalog', {}).fetch('show_images', PAGE_DEFAULTS.fetch('catalog').fetch('show_images')) rescue true
  end
  def catalog_show_images=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['show_images'] = value.to_bool
  end
  def catalog_account_name_and_number
    self.pages.fetch('catalog', {}).fetch('account_name_and_number', PAGE_DEFAULTS.fetch('catalog').fetch('account_name_and_number')) rescue true
  end
  def catalog_account_name_and_number=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['account_name_and_number'] = value.to_bool
  end
  def catalog_stock_level_show
    self.pages.fetch('catalog', {})
        .fetch('stock_level', {}).fetch('show', false) rescue false
  end
  def catalog_stock_level_show=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['stock_level'] ||= {}
    self.pages['catalog']['stock_level']['show'] = value.to_bool
  end
  def catalog_stock_level_sum
    self.pages.fetch('catalog', {})
        .fetch('stock_level', {}).fetch('sum', false) rescue false
  end
  def catalog_stock_level_sum=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['stock_level'] ||= {}
    self.pages['catalog']['stock_level']['sum'] = value.to_bool
  end
  def catalog_stock_level_in_stock_text
    self.pages.fetch('catalog', {})
        .fetch('stock_level', {}).fetch('in_stock_text', '') rescue ''
  end
  def catalog_stock_level_in_stock_text=(value)
    self.pages ||= {}
    self.pages['catalog'] ||= {}
    self.pages['catalog']['stock_level'] ||= {}
    self.pages['catalog']['stock_level']['in_stock_text'] = value
  end

  def product_prev_next_show
    self.pages.fetch('product', {})
        .fetch('prev_next', {}).fetch('show', true) rescue PAGE_DEFAULTS.fetch('product').fetch('prev_next').fetch('show')
  end
  def product_prev_next_show=(value)
    self.pages ||= {}
    self.pages['product'] ||= {}
    self.pages['product']['prev_next'] ||= {}
    self.pages['product']['prev_next']['show'] = value.to_bool
  end

  def product_similar_products
    self.pages.fetch('product', {}).fetch('similar_products', PAGE_DEFAULTS.fetch('product').fetch('similar_products')) rescue true
  end
  def product_similar_products=(value)
    self.pages ||= {}
    self.pages['product'] ||= {}
    self.pages['product']['similar_products'] = value.to_bool
  end

  def variant_default_sort
    sort = self.pages.fetch('default_sorts', {}).fetch('variant', PAGE_DEFAULTS.fetch('default_sorts').fetch('variant')) rescue []
  end
  def variant_default_sort=(value)
    assign_sorts('variant', value)
  end
  def flat_variant_default_sort
    sort = variant_default_sort
    sort.map {|s| s.gsub('full_display_name', 'default_display_name')}
  end
  def flat_or_nested_variant_default_sort
    self.variant_nest_name ? variant_default_sort : flat_variant_default_sort
  end

  def line_item_default_sort
    self.pages.fetch('default_sorts', {}).fetch('line_item', PAGE_DEFAULTS.fetch('default_sorts').fetch('line_item')) rescue []
  end
  def line_item_default_sort=(value)
    assign_sorts('line_item', value)
  end

  def line_item_default_sql_sort
    order_by = line_item_default_sort.map do |s|
      if s.include?('variant')
        "spree_variants.#{s.gsub('variant_', '')}"
      else
        "spree_line_items.#{s}"
      end
    end.join(', ')

    order_by.blank? ? 'spree_line_items.position asc' : order_by
  end

  def standing_line_item_default_sort
    sort = line_item_default_sort
    sort.map{|s| s.gsub('item_name', 'variant_full_display_name')}
  end
  def flat_standing_line_item_default_sort
    sort = line_item_default_sort
    sort.map{|s| s.gsub('item_name', 'variant_default_display_name')}
  end
  def flat_or_nested_standing_line_item_default_sort
    self.variant_nested_name ? standing_line_item_default_sort : flat_standing_line_item_default_sort
  end

  def grouped_line_item_default_sort
    sort = line_item_default_sort
    sort.map{|s| s.gsub('variant_sku', 'sku')}
  end

  def assign_sorts(key, value)
    self.pages ||= {}
    self.pages['default_sorts'] ||= {}
    if value.is_a? Array
      self.pages['default_sorts'][key] = value
    elsif value.is_a? String
      value = value.split(' ')
      new_value = []
      if value.length >= 2
        until value.length == 0
          new_value << "#{value.shift.to_s} #{value.shift.to_s}"
        end
      end

      self.pages['default_sorts'][key] = new_value
    end
  end

  def associated_default_sort(base, association)
    self.method("#{base}_default_sort").call.map do |term|
      term.to_s.split(' ').map do |e|
        if %w[asc desc].include?(e.downcase)
          e
        elsif self.respond_to? "#{association}_#{e}_associated_sort_text"
          self.method("#{association}_#{e}_associated_sort_text").call
        else
          "#{association.to_s}_#{e}"
        end
      end.join(' ')
    end
  end

  def variant_prices_amount_associated_sort_text
    # this is needed to sort avvs
    "price"
  end

  def variant_item_name_associated_sort_text
    # this is needed to sort standing line items
    "full_display_name"
  end
  def flat_variant_item_name_associated_sort_text
    # this is needed to sort standing line items
    "default_display_name"
  end

  def default_sort_column(base, arr_position)
    sort_str = self.method("#{base}_default_sort").call()[arr_position]
    return '' unless sort_str.present?

    sort_str.to_s.split(' ')[0]
  end
  def default_sort_dir(base, arr_position)
    sort_str = self.method("#{base}_default_sort").call()[arr_position]
    return '' unless sort_str.present?

    sort_str.to_s.split(' ')[1]
  end

  def order_success_text
    pages_order_success.fetch('text') rescue ''
  end
  def order_success_text=(value)
    self.pages ||= {}
    self.pages['order_success'] ||= {}
    self.pages['order_success']['text'] = value
  end

  def variant_columns
    {
      'Name' => 'full_display_name',
      'SKU' => 'sku',
      'Pack Size' => 'pack_size',
      'Price' => 'prices_amount',
      'Lead Time' => 'lead_time'
    }
  end

  def line_item_columns
    {
      'Name' => 'item_name',
      'SKU' => 'variant_sku',
      'Pack Size' => 'pack_size',
      'Created At' => 'created_at',
      'Position' => 'position'
    }
  end

  def grouped_line_item_columns
    {
      'Name' => 'item_name',
      'SKU' => 'sku',
      'Pack Size' => 'pack_size'
    }
  end

end
