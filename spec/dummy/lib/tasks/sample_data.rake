# lib/tasks/sample_data.rake
namespace :db do
  desc 'Drop, create, migrate, seed and populate sample data'
  task prepare: [:drop, :create, :migrate, :seed, :load_sample_data] do
    puts 'Ready to go!'
  end

  desc 'Populates the database with sample data'
  task :load_sample_data, [:vendor_name, :currency, :with_variants]=> :environment do |t, args|
    ##############################################################################
    # Create default Permission Groups
    ##############################################################################


    puts "\n\nCreating default permission groups"

    if Spree::PermissionGroup.where(id: nil).blank?
      owner_permission_hash = Spree::Permission.owner_permissions
      owner = Spree::PermissionGroup.new(name: "Owner Access", company_id: nil, permissions: owner_permission_hash, is_default: false)
      owner.save!

      print "."


      staff_permission_hash = Spree::Permission.staff_permissions
      staff = Spree::PermissionGroup.new(name: "Staff Access", company_id: nil, permissions: staff_permission_hash, is_default: true)
      staff.save!

      print "."
    end

    args.with_defaults(vendor_name: 'CSK Wholesale', currency: 'USD', with_variants: false)
    # ["CSK Wholesale, USD, false"]
    args.with_variants = ActiveRecord::Type::Boolean.new.type_cast_from_user(args.with_variants)
    num_customers = 5
    # Setting stdout to be true so we can output without line breaks using 'print'
    $stdout.sync = true

    # How big do we want the seed to get? 1 = small, 2 = medium, 3 = full-size
    @target_size = 3.0

    vendor = Spree::Role.find_or_create_by(name: 'vendor')
    customer = Spree::Role.find_or_create_by(name: 'customer')

    Spree::Taxon.find_or_create_by(name: 'Product Category')

    ####### VENDOR #######
    bill_address = Spree::Address.create(address1: '500 7th Ave', city: 'New York', state_id: Spree::State.find_by_name('New York').id,
                        country: Spree::State.find_by_name('New York').country, zipcode: '10018')

    v1 = Spree::Company.new(bill_address_id: bill_address.id, name: args.vendor_name,
      email: "#{args.vendor_name.squish.downcase.tr(" ","_").gsub(/\s|"|,|'/, '')}_demo@sweetist.co",
      internal_company_number: rand(1000000..9999999).to_s,
      order_cutoff_time: '5PM',
      delivery_minimum: 10.0,
      time_zone: "Eastern Time (US & Canada)"
      )
    v1.save!
    v1.currency = args.currency
    v1.save

    sl1 = v1.stock_locations.create(name: "#{args.vendor_name} Stock Location", address1: v1.bill_address.address1, city: v1.bill_address.city, state_id: v1.bill_address.state.id, country_id: v1.bill_address.country.id, zipcode: v1.bill_address.zipcode)
    sl1.save

    sc1 = v1.shipping_categories.create(name: "Standard")
    sc2 = v1.shipping_categories.create(name: "Over Size")

    tc = Spree::TaxCategory.find_or_create_by(name: "Food")
    pm = Spree::PaymentMethod.find_by_name('Check')
    pm ||= Spree::PaymentMethod.create(type: "Spree::PaymentMethod::Check", name: "Check", description: "", active: true, display_on: "", preferences: {})

    pickup_calc = Spree::Calculator.create(
      type: "Spree::Calculator::Shipping::FlatRate",
      calculable_type: "Spree::ShippingMethod",
      preferences: {amount: 0, :currency => args.currency}
    )

    ship_calc = Spree::Calculator.create(
      type: "Spree::Calculator::Shipping::FlatRate",
      calculable_type: "Spree::ShippingMethod",
      preferences: {amount: 7.00, :currency=>args.currency}
    )

    sm = Spree::ShippingMethod.new(name: "Pick Up", admin_name: 'pick_up', display_on: 'Both', tax_category_id: tc.id)
    sm2 = Spree::ShippingMethod.new(name: "Delivery", admin_name: 'delivery', display_on: 'Both', tax_category_id: tc.id)

    sm.calculator = pickup_calc
    sm2.calculator = ship_calc

    sm.shipping_categories = [sc1, sc2]
    sm2.shipping_categories = [sc1, sc2]

    Spree::Zone.update_all(vendor_id: v1.id)

    sm.zones = Spree::Zone.all
    sm2.zones = Spree::Zone.all

    sm.save!
    sm2.save!


    def adjusted_size(input)
      return ((input*@target_size)/3.0).round(0)
    end

    def image(name, type="jpeg")
      curr_dir = "#{File.expand_path File.dirname(__FILE__)}"
      images_path = "#{curr_dir}/images/"
      path = images_path + "#{name}.#{type}"
      if !File.exist?(path)
        puts "Unable to find seed image for #{name} at #{path}"
        #return false
      else
        File.open(path)
      end
    end

    def submit(order)
      order.state = "complete"
      order.completed_at = order.delivery_date - 1.days
      order.save
    end

    def approve(order)
      order.approver_id = order.vendor.users.first.try(:id)
      order.approved_at = order.delivery_date - 1.days
      order.approved = true
      order.state = 'approved'
      shipment = order.shipments.create(stock_location_id: order.vendor.stock_locations.last.id)
      order.line_items.each do |line_item|
        line_item.ordered_qty = line_item.quantity
        shipment.inventory_units.create(
          order_id: order.id,
          line_item_id: line_item.id,
          variant_id: line_item.variant_id
        )
      end
      order.bookkeeping_documents.create(template: 'packaging_slip')
      order.update_invoice
      shipment.shipping_rates.create(shipping_method_id: Spree::ShippingMethod.first.id)
      shipment.state = 'ready'
      order.shipment_state = 'ready'
      order.save
    end

    def ship(order)
      order.state = 'shipped'
      shipment = order.shipments.first
      shipment.state = 'shipped'
      shipment.shipped_at = order.delivery_date
      shipment.save!
      order.line_items.each do |line_item|
        line_item.shipped_qty = line_item.quantity
        line_item.shipped_total = line_item.shipped_qty * line_item.price
      end
      order.shipment_state = 'shipped'
      order.save
    end

    def receive(order)
      order.state = 'invoice'
      shipment = order.shipments.first
      shipment.state = 'received'
      shipment.receiver_id = order.user_id
      shipment.received_at = order.delivery_date
      shipment.save!
      order.line_items.each do |line_item|
        line_item.confirm_received = true
      end
      order.shipment_state = 'received'
      order.save
    end


    ##############################################################################
    # Create demonstration VENDOR
    ##############################################################################

    puts "\nCreating sample vendor and products."

    ####### VENDOR USER #######
    u1 = Spree::User.create(email: v1.email, firstname: 'Frank', lastname: 'Underwood', phone: Faker::PhoneNumber.phone_number, company_id: v1.id, password: 'password')
    u1.spree_roles << vendor
    u1.save!

    ####### VENDOR STOCK LOCATIONS #######
    # automatically created in after create callback

    ###############################################################################
    # Fake Vendor 1 - :Products, Variants, Orders > Li
    ###############################################################################

    foods=[
    'Dry-Roasted Pine Duck',
    'Smoked Lime & Ginger Trout',
    'Deep-Fried Apple & Lavender Trout',
    'Barbecued Orange Soup',
    'Cinnamon and Pistachio Tart',
    'Dark Chocolate and Passion Fruit Fudge',
    'Apple Pud',
    'Elderberry Cone',
    'Deep-Fried Apricots & Honey Rabbit',
    'Tea-Smoked Nuts & Kebabs',
    'White Chocolate and Cocoa Steamed Pudding',
    'Walnut and Orange Pastry',
    'Coffee Whip',
    'Cranberry Gingerbread',
    'Thermal-Cooked Chili',
    'Broasted Egg & Coconut Duck',
    'Baked Southern-Style Alligator',
    'Oven-Grilled Cocoa & Mushroom Walnuts',
    'Peach and White Chocolate Crispies',
    'Pineapple and Pistachio Jelly',
    'Coconut Jam',
    'Raspberry Ice Lollies',
    'Oven-Grilled Mushroom & Apricot Quail',
    'Pickled Light Beer Lamb',
    'Oven-Grilled Mustard Mussels',
    'Sautéed Lime Herring',
    'Fried Sweet & Fresh Bread',
    'Brined Basil & Mint Scrambled Egg',
    'Cinnamon and Grapefruit Tart',
    'Hazelnut and Rum Bread',
    'Walnut Jelly',
    'Coconut Pie',
    'Sautéed Apples & Walnut Bear',
    'Cooked Herbs & Bear',
    'Gentle-Fried Vinegar Tuna',
    'Engine-Cooked Red Whine Cod',
    'Pan-Fried Mushroom & Apricot Chestnuts',
    'Smoked Egg & Beet Bruschetta',
    'Praline and Banana Fudge',
    'Nutmeg and Guava Pastry',
    'Rum Split',
    'Avocado Pound Cake',
    'Pressure-Fried Lime-Coated Yak',
    'Oven-Grilled Sugar Ostrich',
    'Engine-Cooked Jasmine Scallops',
    'Poached Jasmine Trout',
    'Stuffed Mint Walnuts',
    'Deep-Fried Apricots & Honey Bread',
    'Licorice and Pecan Cake',
    'Pecan and Pistachio Cheesecake',
    'Avocado Fruitcake',
    'Milk Chocolate Crumble',
    'Oven-Baked Herbs & Horse',
    'Cooked Mushroom & Apricot Mutton',
    'Thermal-Cooked Mustard & Thyme Crocodile',
    'Marinated Basil & Lime Tuna',
    'Thermal-Cooked Figs & Olive Potatoes',
    'Baked Rhubarb Pizza',
    'Apple and Date Cobbler',
    'Coconut and Walnut Sundae',
    'Cinnamon Roll',
    'Red Wine Bombe',
    'Fire-Roasted Garlic & Onion Duck',
    'Basted Carrot & Corriander Duck',
    'Steamed Forest Herring',
    'Fire-Grilled Chestnuts & Cod',
    'Cinnamon Tofu',
    'Cucumber & Salad',
    'Cocoa and Elderberry Custard',
    'Pineapple and Lemon Surprise',
    'Gooseberry Cake',
    'Almond Pound Cake'
    ]

    lead_times=['1', '1', '1', '1', '1', '2', '3', '4', '5']
    pack_sizes=['Each', '1 lb.', '10 lbs', 'Case', 'Pallet']

    if args.with_variants
      option_type="Preparation"
      option_values=['Raw', 'Ingredients-only', 'Prepped', 'Cooked', 'Whole-hog']

      ot = Spree::OptionType.find_by_name(option_type.downcase)
      unless ot
        ot=Spree::OptionType.create(name: option_type.downcase, presentation: option_type)
        ovs=[]
        option_values.each do |ov|
          ovs << Spree::OptionValue.create(name: ov.downcase, presentation: ov, option_type_id: ot.id, vendor_id: v1.id)
        end
      end
    end

    available_date = Time.zone.local(2013, 1, 1)

    # Looping through all foods to create products, update SKUs, create variants and stock locations, and upload images
    foods.each do |f|
      p = v1.products.create(name: f, price: rand(0.99..99.99), shipping_category_id: Spree::ShippingCategory.last.try(:id), available_on: available_date, description: Faker::Lorem.sentence, pack_size: pack_sizes.sample)
      p.master.update(sku: rand(10000000...100000000), is_master: true, lead_time: lead_times.sample, track_inventory: false, tax_category_id: tc.id)

      # randomly (1/4 times), lets create a product with multiple variants
      var_rand_count = args.with_variants ? rand(1..16) : 0
      if var_rand_count <= 4 && var_rand_count > 1
        p.option_types << ot # add option type to product

        var_loop_count = 0
        # create multiple variants, up to 4, depending on var_rand_count
        var_rand_count.times do
          # adding option type
          v = p.variants.create(sku: rand(10000000...100000000), price: rand(0.99..99.99), lead_time: lead_times.sample, track_inventory: false, tax_category_id: tc.id)
          v.option_values << ovs[var_loop_count]
          v.save
          v.stock_items.create(stock_location_id: v1.stock_locations.last.id)
          var_loop_count += 1
        end
      else
        m = p.master
        m.stock_items.create(stock_location_id: v1.stock_locations.last.id)
      end


      #p.master.images.create!({:attachment => image(p.name.gsub(/ /,"_").downcase)})

      print "." # For debug, Print out a few dots to let user know seed is working

    end

    ##############################################################################
    # Create Sweet team admin users
    ##############################################################################

    # If asking for an admin user in the seed process is preferred, uncomment the next line and delete the lines below it until the next section
    #Spree::Auth::Engine.load_seed if defined?(Spree::Auth)

    admin = Spree::Role.find_or_create_by(name: 'admin')

    # Internal team first
    unless Spree::User.find_by_email('puja@sweetist.co')
      u1 = Spree::User.create(email: 'puja@sweetist.co', firstname: 'Puja', lastname: "Singh", phone: Faker::PhoneNumber.phone_number, company_id: v1.id, password: 'password')
      u1.spree_roles << admin
      u1.spree_roles << customer
      u1.spree_roles << vendor
      u1.save!
    end
    unless Spree::User.find_by_email('greg@sweetist.co')
      u1 = Spree::User.create(email: 'greg@sweetist.co', firstname: 'Greg', lastname: "Kane", phone: Faker::PhoneNumber.phone_number, company_id: v1.id, password: 'password')
      u1.spree_roles << admin
      u1.spree_roles << customer
      u1.spree_roles << vendor
      u1.save!
    end
    unless Spree::User.find_by_email('ed@sweetist.co')
      u1 = Spree::User.create(email: 'ed@sweetist.co', firstname: 'Ed', lastname: "Chang", phone: Faker::PhoneNumber.phone_number, company_id: v1.id, password: 'password')
      u1.spree_roles << admin
      u1.spree_roles << customer
      u1.spree_roles << vendor
      u1.save!
    end
    unless Spree::User.find_by_email('spiderman@sweetist.co')
      u1 = Spree::User.create(email: 'spiderman@sweetist.co', firstname: 'Spider', lastname: "Man", phone: Faker::PhoneNumber.phone_number, company_id: v1.id, password: 'password')
      u1.spree_roles << admin
      u1.spree_roles << customer
      u1.spree_roles << vendor
      u1.save!
    end


    ##############################################################################
    # Create demonstration CUSTOMERS
    ##############################################################################

    puts "\n\nCreating sample customers and accounts."


    b_type=['Foods', 'Cafe', 'Coffee', 'Bakery', 'Grocery', 'Hotel', 'Airlines', 'Restaurant']

    Spree::PaymentTerm.find_or_create_by(name: 'COD')
    Spree::PaymentTerm.find_or_create_by(name: 'Due on Receipt')
    Spree::PaymentTerm.find_or_create_by(name: 'Credit Card')
    Spree::PaymentTerm.find_or_create_by(name: 'Check')
    Spree::PaymentTerm.find_or_create_by(name: 'Net 5')
    Spree::PaymentTerm.find_or_create_by(name: 'Net 10')
    Spree::PaymentTerm.find_or_create_by(name: 'Net 15')
    Spree::PaymentTerm.find_or_create_by(name: 'Net 30')
    Spree::PaymentTerm.find_or_create_by(name: 'Net 45')
    Spree::PaymentTerm.find_or_create_by(name: 'Net 60')

    adjusted_size(num_customers).times do
    ####### CUSTOMERS #######
      cust_name = Faker::Company.name + " " + b_type.sample # fake business name
      b_email = cust_name.squish.downcase.tr(" ","_").gsub(/\s|"|,|'/, '') + "@sweetist.co"
      c = Spree::Company.create(name: cust_name, internal_company_number: rand(1000000..9999999).to_s, email: "contact_#{b_email}", time_zone: "Eastern Time (US & Canada)")

      ####### REST OF CUSTOMER USERS ARE RANDOM #######
      u_first_name = Faker::Name.first_name
      u_last_name = Faker::Name.last_name
      u_email = (u_first_name + "_" + cust_name).squish.downcase.tr(" ","_").gsub(/\s|"|,|'/, '') + "@sweetist.co"

      u = Spree::User.create(email: u_email, firstname: u_first_name, lastname: u_last_name, phone: Faker::PhoneNumber.phone_number, company_id: c.id, password: 'password')
      u.spree_roles << customer
      u.save

    ####### CUSTOMER SHIP ADDRESSES #######
      c.build_ship_address(firstname: u.firstname, lastname: u.lastname, address1: Faker::Address.street_address, city: Faker::Address.city, zipcode: Faker::AddressUS.zip_code, phone: u.phone, state_id: Spree::State.find_by(name:"Montana", country_id: Spree::Country.find_by(name:"United States").id), company: c.name, country_id: Spree::Country.find_by(name:"United States").id)
      c.save

    ####### ACCOUNT CREATION  #######
      a = v1.customer_accounts.create(payment_terms_id: Spree::PaymentTerm.all.sample.id, customer_id: c.id, number: rand(1000000...10000000).to_s, name: cust_name)
      ua = Spree::UserAccount.create(account_id: a.id, user_id: u.id)
      ua.save

    ####### LOOP THROUGH AND SETUP ACCOUNT VIEWABLE PRODUCTS  #######
      # picking random number of viewable products for a customer
      viewable_prod_count = rand(0..foods.count)

      # for each number of lines, let's setup the line item
      adjusted_size(viewable_prod_count).times do
        p = v1.products.sample
        p.variants_including_master.each do |v|
          unless a.account_viewable_variants.find_by(variant_id: v.id)
            Spree::AccountViewableVariant.create(variant_id: v.id, account_id: a.id, visible: true)
          end
        end

        print "." # For debug, Print out a few dots to let user know seed is working

      end

    end


    ###############################################################################
    # Setting up past orders as seed data to fill charts, etc.
    ###############################################################################

    puts "\n\nCreating sample order and line item data. This may take a few minutes."

    v1.customers.limit(adjusted_size(12)).each do |c|
      12.times do |mo|
        if mo > Date.today.month
          yr="#{Date.today.year-1}"
        else
          yr="#{Date.today.year}"
        end

        o1 = v1.sales_orders.new(customer_id: c.id, ship_address_id: c.ship_address_id, bill_address_id: c.ship_address_id, email: c.email,
          delivery_date: Time.zone.local(yr, mo+1, 28), user_id: Spree::User.where(company_id:c.id).first.id, created_by_id: c.users.first.id, account_id: c.vendor_accounts.first.id, shipping_method_id: Spree::ShippingMethod.first.id)
        o1.save!

        # picking random number of line items in an order
        items_count = rand(4..13)

        # for each number of lines, let's setup the line item
        adjusted_size(items_count).times do
          # picking random product
          options = {}
          quantity = rand(5..50)
          variant = args.with_variants ? v1.variants.sample : v1.products.sample.master
          o1.contents.add(variant, quantity, options)

          print "." # For debug, print out a few dots to let user know seed is working

        end

        item_count = 0
        item_total = 0
        o1.line_items.each do |item|
          item_count += item.quantity
          item_total += (item.quantity * item.price)
        end
        o1.item_count = item_count
        o1.item_total = item_total
        o1.total = item_total

        o1.payments.create(payment_method_id: Spree::PaymentMethod.last.id)
        if o1.delivery_date < Time.current
          o1.state = "complete"
          o1.completed_at = o1.delivery_date
        end

        if o1.delivery_date < Time.current
          submit(o1)
          approve(o1)
          ship(o1)
          receive(o1)
        end
        o1.completed_at = o1.delivery_date - 1.days
        o1.save
      end
    end

    puts "\n\nSample data loaded."

    # puts "\nTo view the vendor management portal, you can use \"demo_vendor@sweetist.co\" as your login."
    # puts "To view the customer portal, you can use \"john_dough@sweetist.co\" as your login."
    # puts "Password for both logins is \"password\"."
  end
end
