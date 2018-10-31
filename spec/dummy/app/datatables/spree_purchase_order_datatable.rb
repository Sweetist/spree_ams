class SpreePurchaseOrderDatatable < SpreeOrderDatatable
  def_delegators :@view,
                 :link_to,
                 :edit_manage_purchase_order_path,
                 :display_vendor_date_format,
                 :html_safe,
                 :display_sweet_price,
                 :manage_vendor_vendor_account_path

  def get_raw_records
    vendor.purchase_orders.joins(:account).includes(:vendor, thread: [comments: :creator])
  end

  def status(order)
    order.state_text
  end

  def account_fully_qualified_name(record)
    link_to manage_vendor_vendor_account_path(record.account.customer, record.account), class: 'orders-list-order-link cel' do
      record.account.fully_qualified_name
    end
  end

  def number(order)
    link_to edit_manage_purchase_order_path(order), class: 'orders-list-order-link cel' do
      if order.viewable_comments?(user)
        "#{order.po_display_number}
          <i class='margin-left-10 fa fa-sticky-note-o' aria-hidden='true'></i>
        ".html_safe
      else
        order.po_display_number
      end
    end
  end

  def pdf_invoice(order)
    if States[order.state] >= States['complete']
      "<a target='_blank' href='/manage/purchase_orders/#{order.number}.pdf'>
        <i class='fa fa-file-pdf-o'></i>
      </a>".html_safe
    end
  end
end
