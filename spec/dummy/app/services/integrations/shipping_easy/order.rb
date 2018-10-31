module Integrations
  module ShippingEasy
    class Order < BaseObject
      include Integrations::Order

      def sync_id
        return @data['sync_id'] if @data['sync_id']
        raise Error, I18n.t('integrations.sync_id_not_found',
                            klass: self.class.name)
      end

      def order_number
        return @data['id'] if @data['id']
        raise Error, I18n.t('integrations.sync_id_not_found',
                            klass: self.class.name)
      end
    end
  end
end
