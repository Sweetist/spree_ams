namespace :db do
  desc 'Add vendor id to account payments'
  task account_payment_prefix: :environment do
    puts 'Begin renumbering'
    Spree::AccountPayment.find_each do |payment|
      next if payment.number.start_with?(payment.prefix_scope)
      payment.update_columns(number: "#{payment.prefix_scope}#{payment.number}")
    end
    puts 'Finished'
  end

end
