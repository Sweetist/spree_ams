module Spree
  class Printables::Order::Item
    extend Spree::DisplayMoney

    attr_accessor :sku, :name, :options_text, :price, :quantity, :total,
                  :currency, :lot_number, :parts, :show_parts, :pack_size,
                  :total_weight, :unit_weight

    money_methods :price, :total

    def initialize(args = {})
      args.each do |key, value|
        send("#{key}=", value)
      end
    end
  end
end
