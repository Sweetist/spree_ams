module Spree
  class ShipmentSerializer < ActiveModel::Serializer
    embed :ids, include: true

    attributes  :id,
                :tracking,
                :number,
                :cost,
                :shipped_at,
                :state,
                :selected_shipping_rate_id

    has_one :stock_location
    # has_many :shipping_rates
    has_many :line_items

    def email
      object.order.email
    end

    def channel
      object.order.channel || 'spree'
    end

    def cost
      object.cost.to_f
    end

    def status
      object.state
    end

    # def stock_location
    #   object.stock_location.name
    # end

    def shipping_method
      object.shipping_method.try(:name)
    end

    def shipping_method_code
      object.shipping_method.try(:code)
    end

    def placed_on
      if object.order.completed_at?
        object.order.completed_at.getutc.try(:iso8601)
      else
        ''
      end
    end

    def shipped_at
      object.shipped_at.try(:iso8601)
    end

    def totals
      {
        item: object.order.item_total.to_f,
        adjustment: adjustment_total,
        tax: tax_total,
        shipping: shipping_total,
        payment: object.order.payments.completed.sum(:amount).to_f,
        order: object.order.total.to_f
      }
    end

    def updated_at
      object.updated_at.iso8601
    end

    def items
      i = []
      object.inventory_units.each do |inventory_unit|
        i << InventoryUnitSerializer.new(inventory_unit, root: false)
      end
      i
    end

    private

    def adjustment_total
      object.order.adjustment_total.to_f
    end

    def shipping_total
      object.order.shipment_total.to_f
    end

    def tax_total
      object.order.tax_total.to_f
    end
  end
end
