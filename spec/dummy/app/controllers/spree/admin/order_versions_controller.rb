class Spree::Admin::OrderVersionsController < Spree::Admin::VersionsController
  before_action :load_order

  def index
    if params[:with_associations]
      query_where = '(item_type = ? and item_id = ?)'
      query_where += ' or (item_type = ? and item_id in (?))'
      query_where += ' or (item_type = ? and item_id in (?))'
      @versions = Spree::Version.where(
        query_where,
        'Spree::Order', @order.id,
        'Spree::LineItem', @order.line_item_ids,
        'Spree::Payment', @order.payment_ids
      ).order(created_at: :desc)
    else
      @versions = @order.versions.reorder(created_at: :desc)
    end
  end

  private

  def load_order
    @order = Spree::Order.friendly.find(params[:order_id])
  end
end
