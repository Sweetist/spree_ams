module Spree
  module Syncable
    extend ActiveSupport::Concern

    def send_request(url, method = :get, payload = {})
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      case method.to_sym.downcase
      when :post
        req = Net::HTTP::Post.new(uri.to_s)
      when :put
        req = Net::HTTP::Put.new(uri.to_s)
      when :patch
        req = Net::HTTP::Put.new(uri.to_s)
      when :delete
        req = Net::HTTP::Delete.new(uri.to_s)
      else
        req = Net::HTTP::Get.new(uri.to_s)
      end
      req.body = payload.to_json
      req['Content-Type'] = 'application/json'
      http.request(req)
    end

  end
end
