class SpreeCreditMemosDatatable < AjaxDatatablesRails::Base
  def_delegators :@view,
                 :link_to,
                 :edit_manage_credit_memo_path,
                 :display_vendor_date_format,
                 :html_safe,
                 :display_sweet_price,
                 :manage_customer_account_path,
                 :sweet_full_date_time

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      checkbox: { source: 'checkbox', cond: :null_value, searchable: false, orderable: false, db_field: false },
      amount_remaining:  { source: 'Spree::CreditMemo.amount_remaining', orderable: true },
      total: { source: 'Spree::CreditMemo.total', orderable: true },
      # state: { source: 'Spree::CreditMemo.state', orderable: true },
      number: { source: 'Spree::CreditMemo.number', orderable: true },
      txn_date: { source: 'Spree::CreditMemo.txn_date', orderable: true },
      created_at: { source: 'Spree::CreditMemo.created_at', orderable: true },
      account_fully_qualified_name: { source: 'Spree::Account.fully_qualified_name', orderable: true }
    }
  end

  def data
    records.map do |record|
      {
        checkbox: checkbox(record),
        txn_date: txn_date(record),
        created_at: created_at(record),
        number: number(record),
        # state: state(record),
        account_fully_qualified_name: account_fully_qualified_name(record),
        amount_remaining: amount_remaining(record),
        total: total(record)
      }
    end
  end

  private

  def state(record)
    "<label class='btn btn-xs circle payment_status #{record.state}'>
      #{Spree.t(record.state, scope: :payment_states, default: [:missing, '']).to_s.titleize}
    </label>".html_safe
  end

  def created_at(record)
    display_vendor_date_format(record.created_at, vendor.date_format)
  end
  def txn_date(record)
    display_vendor_date_format(record.txn_date, vendor.date_format)
  end
  def amount_remaining(record)
    display_sweet_price(record.amount_remaining, record.currency).to_s
  end

  def total(record)
    display_sweet_price(record.total, record.currency).to_s
  end

  def checkbox(record)
    "<div class='checker'>
      <span>
      </span>
    </div>".html_safe
  end

  def get_raw_records
    vendor.credit_memos.joins(:account).includes(:vendor).ransack(ransack_params).result
  end

  def number(record)
    link_to edit_manage_credit_memo_path(record), class: '' do
      record.display_number
    end
  end

  def account_fully_qualified_name(record)
    link_to manage_customer_account_path(record.account.customer, record.account), class: 'orders-list-order-link cel' do
      record.account.fully_qualified_name
    end
  end

  def ransack_params
    return @ransack_params if @ransack_params
    start_date = DateHelper.to_db_from_frontend(options[:ransack_params][:created_at_gteq], vendor)
    end_date = DateHelper.to_db_from_frontend(options[:ransack_params][:created_at_lteq], vendor)
    if start_date.present?
      options[:ransack_params][:created_at_gteq] = start_date.beginning_of_day
    end
    if end_date.present?
      options[:ransack_params][:created_at_lteq] = end_date.end_of_day
    end

    @ransack_params = options[:ransack_params]
  end

  def vendor
    @vendor ||= options[:vendor]
  end

  def user
    @user ||= options[:user]
  end
end
