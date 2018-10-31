module InventoryHistory
  # Allows check Redshift data consistency
  #
  class CheckWarehouseConsistency
    def initialize(args)
      @date_start = Date.parse(args[:date_start]).beginning_of_day
      @date_end = Date.parse(args[:date_end]).end_of_day
      @created_movement_ids = []
    end

    def call
      p '=============================================================='
      movements = Spree::StockMovement
                  .where(created_at: @date_start..@date_end)
      movements.each do |movement|
        second_db_movement = Spree::InventoryChangeHistory
                             .find_by(stock_movement_id: movement.id)

        create_warehouse_line_for(movement) unless second_db_movement
      end
      p '--------------------------------------------------------------'
      p 'Created InventoryChangeHistory IDS'
      p @created_movement_ids
      p '=============================================================='
    end

    private

    def create_warehouse_line_for(movement)
      return unless movement.can_add_in_history?

      result = movement.save_in_history(use_historical_on_hand: true)
      return if result.blank?
      puts "Created missing movemet #{movement.inspect}"
      @created_movement_ids << movement.id
    end
  end
end
