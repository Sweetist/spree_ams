module Spree::QboIntegration::Helper
  def qbo_exchange_rate(currency)
    service = integration_item.qbo_service('ExchangeRate')
    exchange = service.query("Select * from ExchangeRate where SourceCurrencyCode='#{currency}' and AsOfDate='#{Time.current.to_date}'").first
    exchange ||= service.query("Select * from ExchangeRate where SourceCurrencyCode='#{currency}' and AsOfDate='#{Time.current.to_date - 1.day}'").first

    exchange.try(:rate)
  end
end
