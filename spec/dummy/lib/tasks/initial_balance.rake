namespace :balance do
  desc 'Show disbalance on orders'
  task check: :environment do
    Spree::Account.all.each do |account|
      puts "Handle account: #{account.name}"
      account.orders.each do |order|
        puts "     Order not consisted: #{order.number}" if order.not_right_balance?
      end
      puts ' '
    end
  end
  desc 'Create Initial Balance'
  task initial_setup: :check do
    puts 'Fixing balances ...'
    Spree::Account.find_each(&:initial_orders_balance)
    puts 'Done'
  end
end
