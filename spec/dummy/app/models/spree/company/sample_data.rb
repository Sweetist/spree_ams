module Spree::Company::SampleData
  extend ActiveSupport::Concern
  # after_create :set_up_tax_categories
  # after_create :set_up_default_permisssion_groups
  # after_create :set_up_customer_viewable_attribute
  # after_create :set_up_order_rules

  def load_sample_data(skip = {})
    Sidekiq::Client.push(
      'class' => SampleDataWorker,
      'queue' => 'imports',
      'args' => [self.id, skip]
    )
  end
  def load_default_data(skip = {})
    skip.merge!({sample_data: true})
    Sidekiq::Client.push(
      'class' => SampleDataWorker,
      'queue' => 'imports',
      'args' => [self.id, skip]
    )
  end

  def setup_default_data(skip = {})
    setup_stock_locations unless skip[:stock_locations]
    setup_shipping_categories unless skip[:shipping_categories]
    setup_zones unless skip[:zones]
    setup_shipping_methods unless skip[:shipping_methods]
    setup_payment_methods unless skip[:payment_methods]
  end

  def setup_sample_data(skip = {})

    setup_customers unless skip[:customers]
    unless skip[:products_without_variants]
      setup_products_without_variants('Oatmeal Raisin Cookies - 14oz Bag (Sample)',
                                      'ORC14OZ001',
                                      'Oatmeal Raisin Cookies - Case (Sample)',
                                      'ORCCASE001')
      setup_products_without_variants('Peanut Butter Cookies - 14oz Bag (Sample)',
                                      'PBC14OZ001',
                                      'Peanut Butter Cookies - Case (Sample)',
                                      'PBCCASE001')
      setup_products_without_variants('Chocolate Chip Cookies - 14oz Bag (Sample)',
                                      'CCC14OZ001',
                                      'Chocolate Chip Cookies - Case (Sample)',
                                      'CCCCASE001')
      setup_products_with_variants('Cookie T-shirt (Sample)', 'CTS0001')
    end

    setup_price_lists unless skip[:price_lists]
    setup_orders unless skip[:orders]
  end

  def setup_stock_locations
    sl = stock_locations.find_by_name('Default')
    sl ||= self.stock_locations.create(
      name: "Default",
      default: true,
      address1: self.bill_address.address1,
      state_id: self.bill_address.state.try(:id),
      city: self.bill_address.city,
      zipcode: self.bill_address.zipcode,
      country_id: self.bill_address.country_id
    )
  end

  def setup_shipping_categories
    sc = shipping_categories.find_or_create_by(name: 'Default')
    [sc]
  end

  def setup_zones
    zone = zones.find_or_create_by(kind: 'country', name: 'United States')
    Spree::ZoneMember.find_or_create_by(
      zone_id: zone.id,
      zoneable_id: Spree::Country.find_by_name('United States').try(:id),
      zoneable_type: 'Spree::Country'
    )

    [zone]
  end

  def setup_shipping_methods
    tc = tax_categories.find_by_tax_code('Non')
    tc ||= tax_categories.create(name: 'Nontaxable', tax_code: "Non", description: "Default Non-Tax Category" )
    sm = Spree::ShippingMethod.find_or_initialize_by(name: 'Pick Up', tax_category_id: tc.id)
    unless sm.persisted?
      sm.display_on = 'Both'
      sm.admin_name = 'pick_up'
      pickup_calc = Spree::Calculator.create(
        type: "Spree::Calculator::Shipping::FlatRate",
        calculable_type: "Spree::ShippingMethod",
        preferences: {amount: 0, currency: self.currency}
      )
      sm.calculator = pickup_calc
      sm.shipping_categories = setup_shipping_categories
      sm.zones = setup_zones
      sm.save
    end
    sm2 = Spree::ShippingMethod.find_or_initialize_by(name: 'Delivery', tax_category_id: tc.id)
    unless sm2.persisted?
      sm2.admin_name = 'delivery'
      sm2.display_on = 'Both'
      ship_calc = Spree::Calculator.create(
        type: "Spree::Calculator::Shipping::FlatRate",
        calculable_type: "Spree::ShippingMethod",
        preferences: {amount: 10.00, currency: self.currency}
      )
      sm2.calculator = ship_calc
      sm2.shipping_categories = setup_shipping_categories
      sm2.zones = setup_zones
      sm2.save
    end
  end

  def setup_payment_methods
    check = payment_methods.find_by_name('Check')
    check ||= payment_methods.create(type: 'Spree::PaymentMethod::Check', name: 'Check', description: '', active: true, display_on: 'back_end', preferences: {})
    cash = payment_methods.find_by_name('Cash')
    cash ||= payment_methods.create(type: 'Spree::PaymentMethod::Cash', name: 'Cash', description: '', active: true, display_on: 'back_end', preferences: {})
  end

  def setup_products_without_variants(name1, sku1, name2, sku2)
    p1 = products.find_or_initialize_by(name: name1)
    unless p1.persisted?
      tc = tax_categories.find_by_tax_code('Non')
      tc ||= tax_categories.create(name: 'Nontaxable', tax_code: "Non", description: "Default Non-Tax Category" )
      p1.available_on = (Time.current - 1.week).to_date
      m1 = p1.master
      m1.sku = sku1
      m1.price = 5.85
      m1.cost_price = 1.95
      m1.avg_cost_price = 1.95
      p1.tax_category_id = tc.id
      m1.tax_category_id = tc.id
      p1.shipping_category_id = setup_shipping_categories.try(:first).try(:id)
      m1.pack_size = 'Each'
      p1.for_sale = true
      p1.for_purchase = false
      p1.can_be_part = true
      p1.product_type = 'inventory_item'
      m1.variant_type = 'inventory_item'
      m1.weight = 14
      m1.weight_units = 'oz'
      m1.synchronous_avv_create = true

      #TODO set up taxons
      #TODO set up chart of accounts
      p1.save
    end

    p2 = products.find_or_initialize_by(name: name2)
    unless p2.persisted?
      tc = tax_categories.find_by_tax_code('Non')
      tc ||= tax_categories.create(name: 'Nontaxable', tax_code: "Non", description: "Default Non-Tax Category" )
      p2.available_on = (Time.current - 1.week).to_date
      m2 = p2.master
      m2.sku = sku2
      m2.price = 70
      m2.cost_price = 23.40
      m2.sum_cost_price = 23.40
      m2.avg_cost_price = 23.40
      m2.costing_method = 'sum'
      p2.tax_category_id = tc.id
      m2.tax_category_id = tc.id
      p2.shipping_category_id = setup_shipping_categories.try(:first).try(:id)
      m2.pack_size = '12/14oz'
      p2.for_sale = true
      p2.for_purchase = false
      p2.can_be_part = false
      p2.product_type = 'inventory_assembly'
      m2.variant_type = 'inventory_assembly'
      m2.weight = 10.5
      m2.weight_units = 'lb'
      m2.synchronous_avv_create = true

      #TODO set up taxons
      #TODO set up chart of accounts
      p2.save
      Spree::AssembliesPart.create(assembly_id: m2.reload.id, part_id: m1.reload.id, count: 12)
      m1.stock_items.update_all(count_on_hand: 2000, on_hand: 2000)
      m2.stock_items.update_all(count_on_hand: 300, on_hand: 300)
      # parts_variants
    end
  end

  def setup_products_with_variants(name, master_sku)
    p1 = products.find_or_initialize_by(name: name)
    unless p1.persisted?
      tc = tax_categories.find_by_tax_code('Non')
      tc ||= tax_categories.create(name: 'Nontaxable', tax_code: "Non", description: "Default Non-Tax Category" )
      ot1 = option_types.find_or_create_by(name: 'Size', presentation: 'Size')
      ot2 = option_types.find_or_create_by(name: 'Color', presentation: 'Color')

      p1.available_on = (Time.current - 1.week).to_date
      m1 = p1.master
      m1.sku = master_sku
      m1.price = 16.95
      m1.cost_price = 3.20
      p1.tax_category_id = tc.id
      m1.tax_category_id = tc.id
      p1.shipping_category_id = setup_shipping_categories.try(:first).try(:id)
      m1.pack_size = 'Each'
      p1.for_sale = true
      p1.for_purchase = true
      p1.can_be_part = false
      p1.product_type = 'inventory_item'
      m1.variant_type = 'inventory_item'
      m1.weight = 5
      m1.weight_units = 'oz'
      m1.synchronous_avv_create = true

      #TODO set up taxons
      #TODO set up chart of accounts
      p1.save
      p1.product_option_types.create(option_type_id: ot1.id, position: 1)
      p1.product_option_types.create(option_type_id: ot2.id, position: 2)

      ov1 = ot1.option_values.find_or_create_by(name: 'Small', presentation: 'Small', vendor_id: self.id)
      ov2 = ot1.option_values.find_or_create_by(name: 'Medium', presentation: 'Medium', vendor_id: self.id)
      ov3 = ot1.option_values.find_or_create_by(name: 'Large', presentation: 'Large', vendor_id: self.id)
      ot1_ovs = [ov1, ov2, ov3]
      ov4 = ot2.option_values.find_or_create_by(name: 'Black', presentation: 'Black', vendor_id: self.id)
      ov5 = ot2.option_values.find_or_create_by(name: 'Navy', presentation: 'Navy', vendor_id: self.id)
      ov6 = ot2.option_values.find_or_create_by(name: 'Maroon', presentation: 'Maroon', vendor_id: self.id)
      ot2_ovs = [ov4, ov5, ov6]

      n = 1
      ot1_ovs.each do |ot1_ov|
        ot2_ovs.each do |ot2_ov|
          v = m1.dup
          v.is_master = false
          v.sku = "#{m1.sku}-00#{n}"
          n += 1

          v.option_value_ids = [ot1_ov.id, ot2_ov.id]
          v.synchronous_avv_create = true
          v.save
          v.reload.stock_items.update_all(count_on_hand: 1000, on_hand: 1000)
        end
      end
    end
  end

  def setup_customers
    a1 = customer_accounts.find_or_initialize_by(fully_qualified_name:'XYZ Home and Kitchen')
    usa = Spree::Country.find_by_name('United States')
    unless a1.persisted?
      c1 = Spree::Company.create(name: 'XYZ Home and Kitchen (Sample)', time_zone: 'Eastern Time (US & Canada)')
      a1.customer_id = c1.id
      a1.name = 'XYZ Home and Kitchen (Sample)'
      a1.number = '100001SK'
      a1.email = 'xyz_home_and_kitchen_@getsweet.com'
      a1.payment_terms_id = Spree::PaymentTerm.find_by_name('COD').try(:id)
      sa = a1.shipping_addresses.new( company: 'XYZ Home and Kitchen (Sample)',
                                      address1: '350 5th Avenue',
                                      state_id: usa.states.find_by_name('New York').try(:id),
                                      country_id: usa.id,
                                      zipcode: '10018',
                                      city: 'New York',
                                      phone: '1123123321' )
      a1.synchronous_avv_create = true
      a1.save
      ba = sa.dup
      ba.addr_type = 'billing'
      ba.save

      a2 = customer_accounts.new
      a2.customer_id = c1.id
      a2.name = 'New York'
      a2.parent_id = a1.id
      a2.number = '100002SK'
      a2.email = 'xyz_home_and_kitchen_ny@getsweet.com'
      a2.payment_terms_id = Spree::PaymentTerm.find_by_name('COD').try(:id)
      sa = a2.shipping_addresses.new( company: 'XYZ Home and Kitchen (Sample)',
                                      address1: '350 5th Avenue',
                                      state_id: usa.states.find_by_name('New York').try(:id),
                                      country_id: usa.id,
                                      zipcode: '10018',
                                      city: 'New York',
                                      phone: '1123123321' )

      a2.synchronous_avv_create = true
      a2.save
      ba = sa.dup
      ba.addr_type = 'billing'
      ba.save

      a3 = customer_accounts.new
      a3.customer_id = c1.id
      a3.name = 'New Jersey'
      a3.parent_id = a1.id
      a3.number = '100003SK'
      a3.email = 'xyz_home_and_kitchen_nj@getsweet.com'
      a3.payment_terms_id = Spree::PaymentTerm.find_by_name('COD').try(:id)
      sa = a3.shipping_addresses.new( company: 'XYZ Home and Kitchen (Sample)',
                                      address1: '112 Washington St',
                                      state_id: usa.states.find_by_name('New Jersey').try(:id),
                                      country_id: usa.id,
                                      zipcode: '07030',
                                      city: 'Hoboken',
                                      phone: '1567822341' )

      a3.synchronous_avv_create = true
      a3.save
      ba = sa.dup
      ba.addr_type = 'billing'
      ba.save

      contact1 = contacts.find_or_initialize_by(first_name: 'Ima', last_name: 'Beyer')
      unless contact1.persisted?
        contact1.save
        contact1.contact_accounts.create(account_id: a1.id)
        contact1.contact_accounts.create(account_id: a2.id)
        contact1.contact_accounts.create(account_id: a3.id)
      end
      contact2 = contacts.find_or_initialize_by(first_name: 'Sellme', last_name: 'Samples')
      unless contact2.persisted?
        contact2.save
        contact2.contact_accounts.create(account_id: a2.id)
      end
    end #end a1.persisted?

    a4 = customer_accounts.find_or_initialize_by(fully_qualified_name:'ABC Restaurant (Sample)')
    unless a4.persisted?
      c4 = Spree::Company.create(name: 'ABC Restaurant (Sample)', time_zone: 'Eastern Time (US & Canada)')
      a4.customer_id = c4.id
      a4.name = 'ABC Restaurant (Sample)'
      a4.number = '100004FD'
      a4.email = 'abc_restaurant@getsweet.com'
      a4.payment_terms_id = Spree::PaymentTerm.find_by_name('Net 30').try(:id)
      sa = a4.shipping_addresses.new( company: 'ABC Restaurant (Sample)',
                                      address1: '500 7th Avenue',
                                      state_id: usa.states.find_by_name('New York').try(:id),
                                      country_id: usa.id,
                                      zipcode: '10018',
                                      city: 'New York',
                                      phone: '1123124433' )

      a4.synchronous_avv_create = true
      a4.save
      ba = sa.dup
      ba.addr_type = 'billing'
      ba.save
    end

  end

  def setup_price_lists
    pl = price_lists.find_or_initialize_by(name: 'Cookie Monsters (Sample)')
    unless pl.persisted?
      pl.adjustment_method = 'percent'
      pl.adjustment_operator = -1
      pl.adjustment_value = 10

      vars = variants_including_master.where(sku: %w[ORCCASE001 PBCCASE001 CCCCASE001])
      customer_accounts.where(number: %w[100001SK 100002SK 100003SK]).ids.each do |acc_id|
        pl.price_list_accounts.new(account_id: acc_id)
      end
      vars.each do |var|
        pl.price_list_variants.new(variant_id: var.id, price: (var.price * 0.9).round(2))
      end
      vars = products.find_by(name: 'Cookie T-shirt (Sample)').try(:variants) || []
      vars.each do |var|
        pl.price_list_variants.new(variant_id: var.id, price: (var.price * 0.9).round(2))
      end

      update_avvs_by_price_list(pl) if pl.save
    end

    pl2 = price_lists.find_or_initialize_by(name: 'T-Shirt Sales (Sample)')
    unless pl2.persisted?
      vars = products.find_by(name: 'Cookie T-shirt (Sample)').try(:variants) || []
      customer_accounts.where(number: %w[100004FD]).ids.each do |acc_id|
        pl2.price_list_accounts.new(account_id: acc_id)
      end
      vars.each do |var|
        pl2.price_list_variants.new(variant_id: var.id, price: var.price)
      end
      vars = variants_including_master.where(sku: %w[ORC14OZ001 PBC14OZ001 CCC14OZ001])
      vars.each do |var|
        pl2.price_list_variants.new(variant_id: var.id, price: (var.price * 1.1))
      end

      update_avvs_by_price_list(pl2) if pl2.save
    end
  end

  def update_avvs_by_price_list(price_list)
    if price_list.try(:active)
      applicable_avvs = self.account_viewable_variants
        .where(
          "recalculating != ? AND ((variant_id IN (?) AND account_id IN (?)) OR price_list_id = ?)",
          Spree::AccountViewableVariant::RecalculatingStatus['enqueued'],
          price_list.price_list_variants.pluck(:variant_id),
          price_list.account_ids,
          price_list.id
        )
    else
      applicable_avvs = self.account_viewable_variants
        .where(
          "recalculating != ? AND price_list_id = ?",
          Spree::AccountViewableVariant::RecalculatingStatus['enqueued'],
          price_list.id
        )
    end

    if self.set_visibility_by_price_list
      if price_list.try(:active) || price_list.nil?
        avv_account_ids = applicable_avvs.pluck(:account_id).uniq
      else
        avv_account_ids = price_list.account_ids
      end
      self.customer_accounts.joins(price_lists: :price_list_variants)
                              .where(id: avv_account_ids).find_each do |account|
        account.set_catalog_visibility_from_price_lists
      end
    end

    applicable_avvs.update_all(recalculating: Spree::AccountViewableVariant::RecalculatingStatus['backlog'])

    applicable_avvs.each do |avv|
      avv.find_eligible_promotions
      avv.cache_price(avv.eligible_promotions.unadvertised)
    end

  end

  def setup_orders
    today = DateHelper.sweet_today(self.time_zone)
    account = self.customer_accounts.where(fully_qualified_name: 'ABC Restaurant (Sample)').first
    account ||= self.customer_accounts.where('fully_qualified_name ilike ?', '%(Sample)%').sample
    dates = [today - 7.days, today - 5.days, today - 2.days, today, today + 4.days]
    dates.each_with_index do |date, idx|
      next unless account.present?
      o = self.sales_orders.new(account_id: account.id, delivery_date: date)
      o.set_email
      o.ship_address_id = Spree::Address.where(account_id: o.account_id, addr_type: 'shipping').first.try(:id)
      o.bill_address_id = Spree::Address.where(account_id: o.account_id, addr_type: 'billing').first.try(:id)
      o.set_shipping_method
      o.save

      v1 = variants_including_master.where(sku: 'ORC14OZ001').first
      v2 = products.find_by(name: 'Cookie T-shirt (Sample)').try(:variants).try(:first)

      if idx.even?
        quantities = [8 + idx, 5 + idx]
      else
        quantities = [3 + idx, 2 + idx]
      end

      contents = {}

      if v1.present?
        contents.merge!({v1.id.to_s => quantities[0]})
      end
      if v2.present?
        contents.merge!({v2.id.to_s => quantities[1]})
      end

      if contents.present?
        o.contents.add_many(contents, {})
        o.next
        o.approve if date <= today
        o.next if date < today
      else
        o.destroy!
      end

    end

  end

end
