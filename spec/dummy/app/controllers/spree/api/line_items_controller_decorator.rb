Spree::Api::LineItemsController.class_eval do

  private

  def line_items_attributes
    {line_items_attributes: {
        id: params[:id],
        quantity: params[:line_item][:quantity],
        shipped_qty: params[:line_item][:shipped_qty],
        ordered_qty: params[:line_item][:ordered_qty],
        txn_class_id: params[:line_item][:txn_class_id],
        options: line_item_params[:options] || {}
    }}
  end

  def line_item_params
    params.require(:line_item).permit(
        :quantity,
        :shipped_qty,
        :ordered_qty,
        :variant_id,
        :txn_class_id,
        options: line_item_options
    )
  end

end
