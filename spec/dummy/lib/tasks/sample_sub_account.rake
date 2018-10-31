# lib/tasks/sample_data.rake
namespace :db do

  desc 'Populates the database with sample data'
  task :heavy_loaded_account, [:vendor_name, :account_name] => :environment do |t, args|
    args.with_defaults(vendor_name: 'CSK Wholesale', account_name: "McFadden's")
    # ["CSK Wholesale, USD, false"]
    num_sub_accounts = 50
    num_orders = 15
    num_days = 90

    customer = Spree::Role.find_or_create_by(name: 'customer')

    time_zones = ["Pacific Time (US & Canada)", "Eastern Time (US & Canada)"]
    # Setting stdout to be true so we can output without line breaks using 'print'
    $stdout.sync = true


    ####### VENDOR #######
    v1 = Spree::Company.where(name: args.vendor_name).first
    if v1.nil?
      raise Exception.new("Could not find company with name #{args.vendor_name}.")
    end

    ####### Parent Account #######
    pa = v1.customer_accounts.where(fully_qualified_name: args.account_name).first
    usa = Spree::Country.find_by(name:"United States")
    us_states = Spree::State.where(country_id: usa.id)
    us_state_ids = us_states.ids
    cust_name = args.account_name
    if pa.nil? #create company & parent account
      b_email = cust_name.squish.downcase.tr(" ","_").gsub(/\s|"|,|'/, '') + "@sweetist.co"
      c = Spree::Company.create(name: cust_name, email: "contact_#{b_email}", time_zone: time_zones.sample)

      u_first_name = Faker::Name.first_name
      u_last_name = Faker::Name.last_name
      u_email = (u_first_name + "_" + cust_name).squish.downcase.tr(" ","_").gsub(/\s|"|,|'/, '') + "@sweetist.co"

      u = Spree::User.create(email: u_email, firstname: u_first_name, lastname: u_last_name, phone: Faker::PhoneNumber.phone_number, company_id: c.id, password: 'password')
      u.spree_roles << customer
      u.save

      addr = c.build_ship_address(firstname: u.firstname, lastname: u.lastname, address1: Faker::Address.street_address, city: Faker::Address.city, zipcode: Faker::AddressUS.zip_code, phone: u.phone, state_id: us_state_ids.sample, company: c.name, country_id: usa.id)
      c.build_bill_address(firstname: addr.firstname, lastname: addr.lastname, address1: addr.address1, city: addr.city, zipcode: addr.zipcode, phone: addr.phone, state_id: addr.state_id, company: addr.company, country_id: addr.country_id)
      c.save

      pa = v1.customer_accounts.create(payment_terms_id: Spree::PaymentTerm.all.sample.id, customer_id: c.id, number: rand(1000000...10000000).to_s, name: cust_name, email: c.email)
      pa.shipping_addresses.create(firstname: addr.firstname, lastname: addr.lastname, address1: addr.address1, city: addr.city, zipcode: addr.zipcode, phone: addr.phone, state_id: addr.state_id, company: addr.company, country_id: addr.country_id)
      pa.billing_addresses.create(firstname: addr.firstname, lastname: addr.lastname, address1: addr.address1, city: addr.city, zipcode: addr.zipcode, phone: addr.phone, state_id: addr.state_id, company: addr.company, country_id: addr.country_id)
      ua = Spree::UserAccount.create(account_id: pa.id, user_id: u.id)
      ua.save

    end


  ####### CUSTOMER SHIP ADDRESSES #######

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
      shipment.shipping_rates.create(shipping_method_id: order.vendor.shipping_methods.first.id)
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



    ####### ACCOUNT CREATION  #######
    num_sub_accounts.times do |n|

      if n < 50
        state = us_states[n]
      else
        state = us_states.sample
      end
      acc_name = "#{state.abbr}-#{n}"
      full_name = "#{cust_name}:#{acc_name}"

      a = v1.customer_accounts.where(fully_qualified_name: full_name, parent_id: pa.id).first
      if a.nil?
        a_email = cust_name.squish.downcase.tr(" ","_").gsub(/\s|"|,|'/, '') + "_#{acc_name}@sweetist.co"
        a = v1.customer_accounts.create(email: a_email, parent_id: pa.id, payment_terms_id: Spree::PaymentTerm.all.sample.id, customer_id: pa.customer_id, number: rand(1000000...10000000).to_s, name: acc_name)
        c_first_name = Faker::Name.first_name
        c_last_name = Faker::Name.last_name

        a.shipping_addresses.create(firstname: c_first_name, lastname: c_last_name,
                                    address1: Faker::Address.street_address,
                                    city: Faker::Address.city,
                                    zipcode: Faker::AddressUS.zip_code,
                                    state_id: state.id,
                                    company: cust_name,
                                    country_id: usa.id
        )
        a.billing_addresses.create(firstname: c_first_name, lastname: c_last_name,
                                    address1: Faker::Address.street_address,
                                    city: Faker::Address.city,
                                    zipcode: Faker::AddressUS.zip_code,
                                    state_id: state.id,
                                    company: cust_name,
                                    country_id: usa.id
        )
        contact = v1.contacts.create(first_name: c_first_name,
                                     last_name: c_last_name,
                                     email: (c_first_name + "_" + acc_name).squish.downcase.tr(" ","_").gsub(/\s|"|,|'/, '') + "@sweetist.co"
        )
        ca = Spree::ContactAccount.create(account_id: a.id, contact_id: contact.id) if contact.id
      end

    end


    ###############################################################################
    # Setting up past orders as seed data to fill charts, etc.
    ###############################################################################

    puts "\n\nCreating sample order and line item data. This may take a few minutes."
    variants = v1.showable_variants
    v1.customer_accounts.where(parent_id: pa.id).each do |a|
      num_orders.times do |n|
        offset = rand(0..num_days)
        date = Date.today - offset.days

        o1 = v1.sales_orders.new(
          account_id: a.id,
          customer_id: a.customer_id,
          ship_address_id: a.default_ship_address.try(:id),
          bill_address_id: a.bill_address.try(:id),
          email: a.email,
          delivery_date: date,
          user_id: nil, created_by_id: v1.users.first.try(:id) || Spree::User.first.id,
          shipping_method_id: v1.shipping_methods.first.try(:id)
        )
        o1.save!

        # picking random number of line items in an order
        items_count = rand(4..13)

        # for each number of lines, let's setup the line item
        items_count.times do
          # picking random product
          options = {}
          quantity = rand(5..50)
          variant = variants.sample
          o1.contents.add(variant, quantity, options) rescue nil

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

        if o1.delivery_date < Time.current
          o1.state = "complete"
          o1.completed_at = o1.delivery_date
        end

        if o1.delivery_date < Time.current
          submit(o1)
          approve(o1)
          # ship(o1)
          # receive(o1)
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
