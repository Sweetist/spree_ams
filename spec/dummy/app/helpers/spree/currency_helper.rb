module Spree
  module CurrencyHelper
    def currency_options
      currencies = ::Money::Currency.all.map do |currency|
        code = currency.iso_code
        ["#{currency.name} (#{code})", code]
      end
    end

    def display_sweet_price(price, currency)
      Spree::Money.new(price, currency: currency)
    end

    def currency_symbol(currency)
      ::Money::Currency.find(currency).symbol rescue ''
    end

    def self.currency_symbol(currency)
      ::Money::Currency.find(currency).symbol
    end
  end
end
