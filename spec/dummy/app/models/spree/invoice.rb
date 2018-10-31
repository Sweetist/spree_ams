# == Schema Information
#
# Table name: spree_invoices
#
#  id                   :integer          not null, primary key
#  start_date           :datetime
#  end_date             :datetime
#  multi_order          :boolean
#  number               :string
#  state                :string
#  item_total           :decimal(, )
#  total                :decimal(, )
#  adjustment_total     :decimal(, )
#  bill_address_id      :integer
#  ship_address_id      :integer
#  payment_total        :decimal(, )
#  payment_state        :string
#  payment_due_date     :datetime
#  currency             :string
#  shipment_total       :decimal(, )
#  additional_tax_total :decimal(, )
#  promo_total          :decimal(, )
#  included_tax_total   :decimal(, )
#  item_count           :integer
#  account_id           :integer
#  confirm_sent         :boolean
#  confirm_returned     :boolean
#  created_at           :datetime
#  updated_at           :datetime
#  vendor_id            :integer
#  customer_id          :integer
#  due_date             :datetime
#

module Spree
  class Invoice < Spree::Base
    PaymentStates = %w[balance_due pending paid failed void credit_owed updating]
    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    belongs_to :customer, class_name: 'Spree::Company', foreign_key: :customer_id, primary_key: :id

    validates :number, :account_id, :invoice_date, :due_date, presence: true
    validates :number, uniqueness: { scope: :vendor_id }
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id
    has_many :orders, class_name: 'Spree::Order', foreign_key: :invoice_id, primary_key: :id
    has_many :line_items, through: :orders
    has_many :order_payments, through: :orders, source: :payments
    has_many :adjustments, through: :orders, source: :adjustments
    has_many :shipment_adjustments, through: :orders, source: :shipment_adjustments
    has_many :line_item_adjustments, through: :line_items, source: :adjustments

    belongs_to :ship_address, class_name: 'Spree::Address', foreign_key: :ship_address_id, primary_key: :id
    belongs_to :bill_address, class_name: 'Spree::Address', foreign_key: :bill_address_id, primary_key: :id

    has_many :bookkeeping_documents, as: :printable, dependent: :destroy
    has_one :pdf_invoice, -> { where(template: 'invoice') },
            class_name: 'Spree::BookkeepingDocument',
            as: :printable
    delegate :number, :date, to: :pdf_invoice, prefix: true

    after_create :pdf_invoice_for_invoice

    self.whitelisted_ransackable_attributes = %w[number start_date end_date total item_count account_id payment_state payment_total due_date]
		self.whitelisted_ransackable_associations = %w[orders line_items account vendor customer]

    def self.view_editable_attributes
      #should return array of attributes
      ['payment_state']
    end

    def self.find_or_create_for_account_by_delivery_date(account, delivery_date)
      invoice = self.where('account_id = ? AND start_date <= ? AND end_date >= ?', account.id, delivery_date, delivery_date).first
      return invoice unless invoice.nil?

      customer = account.customer
      vendor = account.vendor
      start_date = delivery_date.beginning_of_week + vendor.week_starts_on.days
      start_date -= 1.week if start_date > delivery_date
      end_date = start_date + 6.days

      invoice = self.create!(
        multi_order: true,
        start_date: start_date,
        invoice_date: end_date,
        end_date: end_date,
        payment_state: 'balance_due',
        vendor_id: account.vendor_id,
        account_id: account.id,
        customer_id: account.customer_id,
        number: vendor.generate_invoice_number,
        ship_address_id: account.default_ship_address.try(:id),
        bill_address_id: account.bill_address.try(:id),
        currency: vendor.currency,
        due_date: end_date + account.try(:payment_terms).try(:num_days).to_i.days
      )

      vendor.increase_invoice_number!

      invoice
    end

    # This method will void all associated orders with a voidable state
    def void(user_id)
      last = self.orders.where(state: VoidableStates).count - 1
      if self.orders.where.not(state: VoidableStates).exists?
        self.errors.add(:base, "Some orders for this invoice could not be voided because they have not yet shipped. Please cancel orders instead.")
      end

      self.orders.includes(:shipments).where(state: VoidableStates).each_with_index do |order, idx|
        # update the invoice after the last order
        unless order.void(user_id, idx == last)
          self.errors.add(:order, "#{order.display_number}: #{order.errors.full_messages.join(', ')}")
        end
      end

      self.errors.full_messages.empty?
    end

    def past_due?
      Time.current.to_date > self.due_date && balance_due? rescue false
    end

    def balance_due?
      self.payment_state == 'balance_due'
    end

    def payment_status(use_state = false)
      return self.payment_state if use_state
      if self.payment_state == 'pending'
        'paid'
      else
        self.payment_state
      end
    end

    def determine_payment_state(order_totals_sum)
      invoice_payment_total = self.orders.sum(:payment_total)

      if order_payments.present? && order_payments.valid.size == 0
        'failed'
      elsif orders.pluck(:state).all?{|order_state| %w[void canceled].include?(order_state)} && invoice_payment_total == 0
        'void'
      elsif invoice_payment_total == order_totals_sum
        'paid'
      elsif invoice_payment_total > order_totals_sum
        'credit_owed'
      else
        'balance_due'
      end
    end

    def outstanding_balance
      self.orders.inject(0) { |balance, order| balance + order.outstanding_balance }
    end

    def update_counts
      if self.multi_order
        self.update_multi_counts
      else
        self.update_one_to_one_counts(self.orders.first)
      end
    end

    def update_multi_counts
      order_totals = Spree::Order.find_by_sql(["
      SELECT
        sum(item_total) as item_totals,
        sum(total) as totals,
        sum(adjustment_total - promo_total - additional_tax_total - included_tax_total) as adjustment_totals,
        sum(shipment_total) as shipment_totals,
        sum(additional_tax_total) as additional_tax_totals,
        sum(promo_total) as promo_totals,
        sum(included_tax_total) as included_tax_totals,
        sum(item_count) as item_counts
      FROM
        spree_orders
      WHERE
        invoice_id = ? AND state IN (?)
        ", self.id, InvoiceableStates])
      invoice = order_totals.first

      if invoice
        void_invoice = self.orders.pluck(:state).uniq == ['void']
        self.update_columns(
          item_total: invoice.item_totals || 0,
          total: invoice.totals || 0,
          state: void_invoice ? 'void' : nil,
          payment_state: self.determine_payment_state(invoice.totals || 0),
          adjustment_total: invoice.adjustment_totals || 0,
          shipment_total: invoice.shipment_totals || 0,
          additional_tax_total: invoice.additional_tax_totals|| 0,
          promo_total: invoice.promo_totals || 0,
          included_tax_total: invoice.included_tax_totals || 0,
          item_count: invoice.item_counts || 0,
          updated_at: Time.current
        )

        self.orders.update_all(invoice_date: self.invoice_date, due_date: self.due_date)
      else
        self.destroy!
      end
    end

    def update_one_to_one_counts(order)
      self.update_columns(
        state: order.state,
        item_total: order.item_total,
        total: order.total,
        payment_state: order.payment_state,
        start_date: order.delivery_date,
        end_date: order.delivery_date,
        adjustment_total: order.adjustment_total - order.promo_total - order.additional_tax_total - order.included_tax_total,
        shipment_total: order.shipment_total,
        additional_tax_total: order.additional_tax_total,
        promo_total: order.promo_total,
        included_tax_total: order.included_tax_total,
        item_count: order.item_count,
        updated_at: Time.current,
        invoice_date: order.invoice_date,
        due_date: order.due_date
      )
    end

    def self.create_from_one_order(order)
      return order.invoice if order.invoice
      vendor = order.vendor
      sequential = vendor.use_sequential_invoice_number?
      invoice = order.build_invoice(
        multi_order: false,
        account_id: order.account_id,
        customer_id: order.customer_id,
        vendor_id: order.vendor_id,
        number: sequential ? vendor.generate_invoice_number : order.display_number,
        state: order.state,
        payment_state: order.payment_state,
        ship_address_id: order.ship_address_id,
        bill_address_id: order.bill_address_id,
        item_total: order.item_total,
        total: order.total,
        start_date: order.delivery_date,
        end_date: order.delivery_date,
        currency: order.currency,
        adjustment_total: order.adjustment_total - order.promo_total - order.additional_tax_total - order.included_tax_total,
        shipment_total: order.shipment_total,
        additional_tax_total: order.additional_tax_total,
        promo_total: order.promo_total,
        included_tax_total: order.included_tax_total,
        item_count: order.item_count,
        updated_at: Time.current,
        invoice_date: order.invoice_date,
        due_date: order.due_date
      )

      if invoice.save
        invoice.orders << order
        vendor.increase_invoice_number! if sequential
        invoice
      else
        begin
          raise ArgumentError.new("Error creating invoice: #{invoice.errors.full_messages.join('; ')}")
        rescue ArgumentError => e
          Airbrake.notify(
            error_message: "#{e.class.to_s} - #{e.message}",
            error_class: "Invoice Create",
            parameters: {
              vendor_id: order.vendor_id,
              account_id: order.account_id,
              order_id: order.id,
              order_number: order.number,
              invoice_number: invoice.try(:number)
            }
          )
        end
      end
    end

    def mark_paid
      if orders.count == 1
        if orders.first.mark_paid
          self.reload.update_counts
          self.reload
          true
        else
          self.reload.update_counts
          self.errors.add(:base, 'Could not mark PAID')
          false
        end
      else
        self.update_columns(payment_state: 'updating')
        self.orders.where.not(payment_state: 'paid').update_all(payment_state: 'updating')
        self.reload
        Sidekiq::Client.push(
          'class' => MarkPaid,
          'queue' => 'critical',
          'args' => [vendor_id, 'Spree::Invoice', [id]]
        )
        true
      end
    end

    def mark_unpaid
      self.orders.each {|order| order.mark_unpaid(false)}
      self.reload
      self.update_counts
    end

    def send_invoice
      if self.multi_order
        Spree::InvoiceMailer.weekly_invoice_email(self.id, true, true).deliver_later
      else
        Spree::OrderMailer.final_invoice_email(self.try(:orders).try(:first), true, true).deliver_later
      end
      self.update_columns(confirm_sent: true)
    end

    def send_reminder
      Spree::InvoiceMailer.reminder_email(self.id, true).deliver_later
      self.update_columns(confirm_sent: true)
    end

    def display_date
      if self.multi_order?
        "#{DateHelper.display_vendor_date_format(self.start_date, self.vendor.date_format)} - #{DateHelper.display_vendor_date_format(self.end_date, self.vendor.date_format)}"
      else
        "#{DateHelper.display_vendor_date_format(self.invoice_date, self.vendor.date_format)}"
      end
    end

    def display_due_date
      "#{DateHelper.display_vendor_date_format(self.due_date, self.vendor.date_format)}"
    end

    def display_invoice_date
      "#{DateHelper.display_vendor_date_format(self.invoice_date, self.vendor.date_format)}"
    end

    def customer
      self.account
    end

    def email
      self.account.email
    end

    def po_number
      if self.multi_order?
        nil
      else
        self.orders.first.try(:po_number)
      end
    end

    def line_items
      if self.multi_order
        items = self.grouped_line_items
      else
        items = self.orders.first.try(:line_items)
        items ||= []
      end

      items
    end

    def pdf_file
      ActiveSupport::Deprecation.warn('This API has changed: Please use invoice.pdf_invoice.pdf instead')
      pdf_invoice.pdf
    end

    def pdf_filename
      ActiveSupport::Deprecation.warn('This API has changed: Please use invoice.pdf_invoice.file_name instead')
      pdf_invoice.file_name
    end

    def pdf_file_path
      ActiveSupport::Deprecation.warn('This API has changed: Please use invoice.pdf_invoice.pdf_file_path instead')
      pdf_invoice.pdf_file_path
    end

    def pdf_storage_path(template)
      ActiveSupport::Deprecation.warn('This API has changed: Please use invoice.{pdf_invoice}.pdf_file_path instead')
      bookkeeping_documents.find_by!(template: template).file_path
    end

    def pdf_invoice_for_invoice
      self.pdf_invoice.present? ? self.pdf_invoice : bookkeeping_documents.create(template: 'invoice')
    end

    def grouped_line_items
      Spree::LineItem.find_by_sql([
      "
      SELECT
        (spree_line_items.price - spree_line_items.price_discount) as discount_price,
        SUM((spree_line_items.price - spree_line_items.price_discount) * spree_line_items.quantity) as amount,
        SUM(spree_line_items.quantity) as quantity,
        spree_line_items.item_name as item_name,
        spree_line_items.price as price,
        spree_line_items.price_discount as price_discount,
        spree_line_items.currency as currency,
        spree_line_items.lot_number as lot_number,
        spree_variants.id,
        spree_line_items.variant_id,
        spree_line_items.pack_size as pack_size,
        spree_variants.sku as sku
      FROM
        spree_line_items
        JOIN spree_variants ON spree_variants.id = spree_line_items.variant_id
        JOIN spree_orders ON spree_orders.id = spree_line_items.order_id
        JOIN spree_invoices ON spree_orders.invoice_id = spree_invoices.id
      WHERE
        spree_invoices.id = ? AND spree_orders.state IN (?)
      GROUP BY
        item_name, discount_price, spree_line_items.currency, spree_line_items.lot_number, spree_line_items.price, spree_line_items.price_discount, spree_variants.sku, spree_line_items.variant_id, spree_variants.id, spree_line_items.pack_size
      ORDER BY
        #{self.grouped_line_order_by}
      ", self.id, InvoiceableStates])
    end

    def grouped_line_order_by
      default = 'item_name ASC'
      cva = self.vendor.try(:cva)

      return default unless cva
      sort_by = ''
      if cva.grouped_line_item_default_sort.present?
        if cva.grouped_line_item_columns.values.any?{|col| col == cva.default_sort_column('grouped_line_item', 0)}
          sort_by = cva.grouped_line_item_default_sort[0]
        end
        if cva.grouped_line_item_columns.values.any?{|col| col == cva.default_sort_column('grouped_line_item', 1)}
          if sort_by.blank?
            sort_by = cva.grouped_line_item_default_sort[1]
          else
            sort_by = "#{sort_by}, #{cva.line_item_default_sort[1]}"
          end
        end
      end

      sort_by.present? ? sort_by : default
    end
  end
end
