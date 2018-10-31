# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# BEGIN DEFAULT SPREE SEED
Spree::Core::Engine.load_seed if defined?(Spree::Core)

store=Spree::Store.first
store.mail_from_address="no_reply@onsweet.co"
store.url="onsweet.co"
store.name="Sweet Wholesale"
store.save


##############################################################################
# Create admin user
##############################################################################

# If asking for an admin user in the seed process is preferred, uncomment the next line and delete the lines below it until the next section
#Spree::Auth::Engine.load_seed if defined?(Spree::Auth)

admin = Spree::Role.find_or_create_by(name: 'admin')
vendor = Spree::Role.find_or_create_by(name: 'vendor')
customer = Spree::Role.find_or_create_by(name: 'customer')

u = Spree::User.create(email: 'admin@onsweet.co', firstname: 'Pee-wee', lastname: "Herman", phone: Faker::PhoneNumber.phone_number, password: 'password')
u.generate_spree_api_key! # generate api key
u.spree_roles << admin
u.spree_roles << vendor
u.spree_roles << customer
u.save!

puts "\n\nSeed completed successfully."

puts "\nAdmin user \"admin@onsweet.co\" created."

puts "\nTo create a new admin user, run \"bundle exec rake spree_auth:admin:create\" in your terminal."
