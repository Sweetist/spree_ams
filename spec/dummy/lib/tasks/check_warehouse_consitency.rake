desc 'Check warehouse consistency'
task :check_warehouse_consistency,
     %i[date_start date_end] => [:environment] do |_t, args|

  args.with_defaults(date_start: 30.day.ago.to_s, date_end: Time.current.to_s)
  puts "Hello start #{args.date_start}. #{args.date_end}"
  InventoryHistory::CheckWarehouseConsistency.new(args).call
end
