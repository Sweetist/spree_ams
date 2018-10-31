class SpreeOrderDatatable < AjaxDatatablesRails::Base

  def_delegators :@view, :link_to, :edit_manage_order_path, :display_vendor_date_format, :html_safe,
                 :display_sweet_price, :manage_customer_account_path

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      checkbox:                       { source: 'checkbox', cond: :null_value, searchable: false, orderable: false, db_field: false },
      number:                         { source: 'Spree::Order.number', orderable: true },
      delivery_date:                  { source: 'Spree::Order.delivery_date', orderable: true },
      invoice_date:                   { source: 'Spree::Order.invoice_date', orderable: true },
      created_at:                     { source: 'Spree::Order.created_at', orderable: true },
      account_fully_qualified_name:   { source: 'Spree::Account.fully_qualified_name', orderable: true },
      item_count:                     { source: 'Spree::Order.item_count', name: 'Total Items', orderable: true },
      total:                          { source: 'Spree::Order.total', orderable: true },
      sales_channel:                  { source: 'Spree::Order.channel', searchable: true, orderable: true },
      status:                         { source: 'Spree::Order.state', searchable: true, orderable: false },
      payment_status:                 { source: 'Spree::Order.payment_state', searchable: true, orderable: true },
      approved_at:                    { source: 'Spree::Order.approved_at', searchable: true, orderable: true },
      completed_at:                   { source: 'Spree::Order.completed_at', searchable: true, orderable: true },
      stock_location:                 { source: 'Spree::Order.stock_location', searchable: true, orderable: true }
    }
  end

  def data
    records.map do |record|
      {
        checkbox: checkbox(record),
        number: number(record),
        delivery_date: delivery_date(record),
        completed_at: completed_at(record),
        approved_at: approved_at(record),
        invoice_date: invoice_date(record),
        created_at: created_at(record),
        account_fully_qualified_name: account_fully_qualified_name(record),
        item_count: item_count(record),
        sales_channel: sales_channel(record),
        total: total(record),
        status: status(record),
        payment_status: payment_status(record),
        pdf_invoice: pdf_invoice(record),
        stock_location: stock_location(record)
      }
    end
  end

  private

  def ransack_params
    @ransack_params ||= options[:ransack_params]
  end

  def vendor
    @vendor ||= options[:vendor]
  end

  def user
    @user ||= options[:user]
  end

  def get_raw_records
    vendor.sales_orders.joins(:account).includes(:vendor, thread: [comments: :creator])
  end

  def checkbox(record)
    "<div class='checker'>
      <span>
        <input name='company[sales_orders_attributes][#{record.id}][action]' type='hidden' value='0'>
        <input class='checkboxes' type='checkbox' value='1' name='company[sales_orders_attributes][#{record.id}][action]' id='company_sales_orders_attributes_#{record.id}_action'>
        <input type='hidden' value='#{record.id}' name='company[sales_orders_attributes][#{record.id}][id]' id='company_sales_orders_attributes_#{record.id}_id'>
      </span>
    </div>".html_safe
  end

  def pdf_invoice(order)
    if order.invoice_id
      "<a target='_blank' href='/manage/invoices/#{order.invoice_id}.pdf'>
        <i class='fa fa-file-pdf-o'></i>
      </a>".html_safe
    end
  end

  def sales_channel(order)
    Spree.t(order.channel)
  end

  def status(order)
    order.state == 'complete' ? 'Submitted' : order.state.capitalize
  end

  def payment_status(order)
    pm_status = order.payment_status(true)
    "<label class='btn btn-xs circle payment_status #{pm_status}' data-order-id='#{order.id}'>
      #{Spree.t(pm_status, scope: :payment_statuses, default: [:missing, '']).to_s.titleize}
    </label>".html_safe
  end

  def number(order)
    link_to edit_manage_order_path(order), class: 'orders-list-order-link cel' do
      if order.viewable_comments?(user)
        "#{order.display_number}
          <i class='margin-left-10 fa fa-sticky-note-o' aria-hidden='true'></i>
        ".html_safe
      else
        order.display_number
      end
    end
  end

  def total(record)
    display_sweet_price(record.total, record.currency).to_s
  end

  def item_count(record)
    record.item_count.to_s
  end

  def account_fully_qualified_name(record)
    link_to manage_customer_account_path(record.account.customer, record.account), class: 'orders-list-order-link cel' do
      record.account.fully_qualified_name
    end
  end

  def delivery_date(record)
    display_vendor_date_format(record.delivery_date, vendor.date_format)
  end

  def completed_at(record)
    display_vendor_date_format(record.completed_at, vendor.date_format)
  end

  def approved_at(record)
    display_vendor_date_format(record.approved_at, vendor.date_format)
  end

  def invoice_date(record)
    display_vendor_date_format(record.invoice_date, vendor.date_format)
  end

  def created_at(record)
    record.created_at
  end

  def stock_location(record)
    record.shipments[0].try(:stock_location).try(:name).to_s
  end
end

module AjaxDatatablesRails
  module ORM
    module ActiveRecord
      def filter_records(records)
        if ransack_params[:payment_state_in]
          payment_states = ransack_params[:payment_state_in]
          ransack_params.delete(:payment_state_in)
          recs = records.where(payment_state: payment_states)
                 .ransack(ransack_params).result
          ransack_params[:payment_state_in] = payment_states
          recs
        else
          records.ransack(ransack_params).result
        end
      end
    end
  end
end
