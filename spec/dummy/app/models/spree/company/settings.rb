module Spree::Company::Settings
  extend ActiveSupport::Concern
  included do
    attr_default :settings do
      {
        'show_suggested_price' => false,
        'line_item_tax_categories' => false,
        'currency' => 'USD',
        'date_format' => 'mm/dd/yyyy',
        'allow_variants' => true,
        'multi_order_invoice' => false,
        'week_starts_on' => 0,
        'last_editable_order_state' => 6,
        'track_inventory_levels' => false,
        'lot_tracking' => false,
        'auto_assign_lots' => true,
        'show_account_balance' => false,
        'order_date_text' => 'delivery',
        'receive_orders' => false,
        'use_separate_invoices' => false,
        'auto_approve_orders' => false,
        'txn_class_type' => 'none',
        'hard_cutoff_time' => false,
        'hard_lead_time' => true,
        'use_external_balance' => false,
        'hide_empty_orders' => false,
        'set_visibility_by_price_list' => true,
        'only_price_list_pricing' => true,
        'use_price_lists' => true,
        'resubmit_orders' => 'never',
        'use_variant_text_options' => false,
        'send_mail' => {
          'confirm_email' => false,
          'approved_email' => false,
          'approved_email_attach_invoice' => false,
          'approved_email_b2b_and_standing_only' => false,
          'review_order_email' => false,
          'cancel_email' => false,
          'shipped_email' => false,
          'shipped_email_attach_invoice' => false,
          'final_invoice_email' => false,
          'final_invoice_email_attach_invoice' => false,
          'weekly_invoice_email' => false,
          'unapprove' => false,
          'so_create_email' => false,
          'so_update_email' => false,
          'so_create_error_email' => false,
          'so_process_error_email' => false,
          'mail_to_my_company' => false,
          'cc_to_my_company' => false,
          'daily_shipping_reminder' => false,
          'include_website_url_in_emails' => false,
          'invoice_reminder' => false,
          'invoice_reminder_days' => 7,
          'invoice_past_due' => false,
          'invoice_past_due_days' => 3
        },
        'notifications' => {
          'daily_summary' => true,
          'daily_shipping_reminder' => false,
          'confirm_email' => true,
          'review_order_email' => true,
          'discontinued_product_email' => false,
          'low_stock' => false
        }
      }
    end
  end

  def show_suggested_price
    settings['show_suggested_price']
  end
  def show_suggested_price=(value)
    settings['show_suggested_price']=value.to_bool
  end
  def line_item_tax_categories
    settings['line_item_tax_categories'].to_bool
  end
  def line_item_tax_categories=(value)
    settings['line_item_tax_categories'] = value.to_bool
  end
  def date_format
    settings['date_format'] || 'mm/dd/yyyy'
  end
  def date_format=(date_format)
    settings['date_format'] = date_format
  end
  def currency
    settings['currency']
  end
  def currency=(currency)
    settings['currency'] = currency
  end
  def allow_variants
    settings['allow_variants']
  end
  def allow_variants=(value)
    settings['allow_variants'] = value.to_bool
  end
  def multi_order_invoice
    settings['multi_order_invoice']
  end
  def multi_order_invoice=(value)
    settings['multi_order_invoice'] = value.to_bool
  end
  def week_starts_on
    settings['week_starts_on'].to_i
  end
  def week_starts_on=(value)
    settings['week_starts_on'] = value.to_i
  end
  def last_editable_order_state
    settings['last_editable_order_state']
  end
  def last_editable_order_state=(value)
    settings['last_editable_order_state'] = value.to_i
  end
  def track_inventory
    settings['track_inventory_levels']
  end
  def track_inventory=(value)
    settings['track_inventory_levels'] = value.to_bool
  end
  def lot_tracking
    settings['lot_tracking']
  end
  def lot_tracking=(value)
    settings['lot_tracking'] = value.to_bool
  end
  def auto_assign_lots
    settings.fetch('auto_assign_lots', true)
  end
  def auto_assign_lots=(value)
    settings['auto_assign_lots'] = value.to_bool
  end
  def show_account_balance
    settings.fetch('show_account_balance', false)
  end
  def show_account_balance=(value)
    settings['show_account_balance'] = value.to_bool
  end
  def hard_cutoff_time
    settings.fetch('hard_cutoff_time', false)
  end
  def hard_cutoff_time=(value)
    settings['hard_cutoff_time'] = value.to_bool
  end
  def hard_lead_time
    settings.fetch('hard_lead_time', true)
  end
  def hard_lead_time=(value)
    settings['hard_lead_time'] = value.to_bool
  end
  def use_external_balance
    settings.fetch('use_external_balance', false)
  end
  def use_external_balance=(value)
    settings['use_external_balance'] = value.to_bool
  end
  def hide_empty_orders
    settings.fetch('hide_empty_orders', false)
  end
  def hide_empty_orders=(value)
    settings['hide_empty_orders'] = value.to_bool
  end
  def selectable_delivery
    settings['order_date_text'].present?
  end
  def order_date_text
    settings['order_date_text'] || 'delivery'
  end
  def order_date_text=(value)
    settings['order_date_text'] = value
  end
  def receive_orders
    settings['receive_orders']
  end
  def receive_orders=(value)
    settings['receive_orders'] = value.to_bool
  end
  def use_separate_invoices
    settings.fetch('use_separate_invoices', false) || multi_order_invoice
  end
  def use_separate_invoices=(value)
    settings['use_separate_invoices'] = value.to_bool
  end
  def auto_approve_orders
    settings['auto_approve_orders']
  end
  def auto_approve_orders=(value)
    settings['auto_approve_orders'] = value.to_bool
  end
  def txn_class_type
    settings['txn_class_type'] || 'none'
  end
  def txn_class_type=(value)
    settings['txn_class_type'] = value
  end
  def set_visibility_by_price_list
    settings['set_visibility_by_price_list'].to_bool
  end
  def set_visibility_by_price_list=(value)
    settings['set_visibility_by_price_list'] = value.to_bool
  end
  def only_price_list_pricing
    settings['only_price_list_pricing'].to_bool
  end
  def only_price_list_pricing=(value)
    settings['only_price_list_pricing'] = value.to_bool
  end
  def use_price_lists
    settings['use_price_lists'].to_bool
  end
  def use_price_lists=(value)
    settings['use_price_lists'] = value.to_bool
  end
  def resubmit_orders
    settings['resubmit_orders'] || 'never'
  end
  def resubmit_orders=(value)
    settings['resubmit_orders'] = value
  end
  def use_variant_text_options
    settings['use_variant_text_options'].to_bool
  end
  def use_variant_text_options=(value)
    settings['use_variant_text_options'] = value.to_bool
  end

  # BEGIN CUSTOMER COMM SETTINGS
  def send_confirm_email
    settings.fetch('send_mail',{}).fetch('confirm_email', true)
  end
  def send_confirm_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['confirm_email'] = value.to_bool
  end

  def send_approved_email
    settings.fetch('send_mail',{}).fetch('approved_email', true)
  end
  def send_approved_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['approved_email'] = value.to_bool
  end
  # email attach pdf invoice
  def send_approved_email_invoice
    settings.fetch('send_mail',{}).fetch('approved_email_attach_invoice', false)
  end
  def send_approved_email_invoice=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['approved_email_attach_invoice'] = value.to_bool
  end
  def send_approved_email_b2b_and_standing_only
    settings.fetch('send_mail',{}).fetch('approved_email_b2b_and_standing_only', false)
  end
  def send_approved_email_b2b_and_standing_only=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['approved_email_b2b_and_standing_only'] = value.to_bool
  end

  def send_review_order_email
    settings.fetch('send_mail',{}).fetch('review_order_email', true)
  end
  def send_review_order_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['review_order_email'] = value.to_bool
  end

  def send_cancel_email
    settings.fetch('send_mail',{}).fetch('cancel_email', true)
  end
  def send_cancel_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['cancel_email'] = value.to_bool
  end

  def send_final_invoice_email
    settings.fetch('send_mail',{}).fetch('final_invoice_email', true)
  end
  def send_final_invoice_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['final_invoice_email'] = value.to_bool
  end
  # pdf3
  def send_final_invoice_email_invoice
    settings.fetch('send_mail',{}).fetch('final_invoice_email_attach_invoice', false)
  end
  def send_final_invoice_email_invoice=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['final_invoice_email_attach_invoice'] = value.to_bool
  end

  def send_weekly_invoice_email
    settings.fetch('send_mail',{}).fetch('weekly_invoice_email', true)
  end
  def send_weekly_invoice_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['weekly_invoice_email'] = value.to_bool
  end

  def send_unapprove_email
    settings.fetch('send_mail',{}).fetch('unapprove', true)
  end
  def send_unapprove_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['unapprove'] = value.to_bool
  end

  def send_shipped_email
    settings.fetch('send_mail',{}).fetch('shipped_email', true)
  end
  def send_shipped_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['shipped_email'] = value.to_bool
  end
  # pdf2
  def send_shipped_email_invoice
    settings.fetch('send_mail',{}).fetch('shipped_email_attach_invoice', false)
  end
  def send_shipped_email_invoice=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['shipped_email_attach_invoice'] = value.to_bool
  end

  def send_so_create_email
    settings.fetch('send_mail',{}).fetch('so_create_email', true)
  end
  def send_so_create_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['so_create_email'] = value.to_bool
  end

  def send_so_update_email
    settings.fetch('send_mail',{}).fetch('so_update_email', true)
  end
  def send_so_update_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['so_update_email'] = value.to_bool
  end

  def send_so_create_error_email
    settings.fetch('send_mail',{}).fetch('so_create_error_email', true)
  end
  def send_so_create_error_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['so_create_error_email'] = value.to_bool
  end

  def send_so_process_error_email
    settings.fetch('send_mail',{}).fetch('so_process_error_email', true)
  end
  def send_so_process_error_email=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['so_process_error_email'] = value.to_bool
  end

  def send_mail_to_my_company
    settings.fetch('send_mail',{}).fetch('mail_to_my_company', false)
  end
  def send_mail_to_my_company=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['mail_to_my_company'] = value.to_bool
  end

  def send_cc_to_my_company
    settings.fetch('send_mail',{}).fetch('cc_to_my_company', true)
  end
  def send_cc_to_my_company=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['cc_to_my_company'] = value.to_bool
  end

  def send_shipping_reminder
    settings.fetch('send_mail',{}).fetch('daily_shipping_reminder', false)
  end
  def send_shipping_reminder=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['daily_shipping_reminder'] = value.to_bool
  end

  def include_website_url_in_emails
    settings.fetch('send_mail',{}).fetch('include_website_url_in_emails', false)
  end
  def include_website_url_in_emails=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['include_website_url_in_emails'] = value.to_bool
  end

  def send_invoice_reminder
    settings.fetch('send_mail',{}).fetch('invoice_reminder', false)
  end
  def send_invoice_reminder=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['invoice_reminder'] = value.to_bool
  end

  def send_invoice_past_due
    settings.fetch('send_mail',{}).fetch('invoice_past_due', false)
  end
  def send_invoice_past_due=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['invoice_past_due'] = value.to_bool
  end

  def invoice_reminder_days
    settings.fetch('send_mail',{}).fetch('invoice_reminder_days', 0).to_i
  end
  def invoice_reminder_days=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['invoice_reminder_days'] = value.to_i
  end

  def invoice_past_due_days
    settings.fetch('send_mail',{}).fetch('invoice_past_due_days', 0).to_i
  end
  def invoice_past_due_days=(value)
    settings['send_mail'] ||= {}
    settings['send_mail']['invoice_past_due_days'] = value.to_i
  end
  # END CUSTOMER COMM SETTINGS
  # BEGIN NOTIFICATION SETTINGS
  def notify_daily_summary
    settings.fetch('notifications',{}).fetch('daily_summary', true)
  end
  def notify_daily_summary=(value)
    settings['notifications'] ||= {}
    settings['notifications']['daily_summary'] = value.to_bool
  end

  def notify_daily_shipping_reminder
    settings.fetch('notifications',{}).fetch('daily_shipping_reminder', false)
  end
  def notify_daily_shipping_reminder=(value)
    settings['notifications'] ||= {}
    settings['notifications']['daily_shipping_reminder'] = value.to_bool
  end

  def notify_order_confirmation
    settings.fetch('notifications',{}).fetch('confirm_email', true)
  end
  def notify_order_confirmation=(value)
    settings['notifications'] ||= {}
    settings['notifications']['confirm_email'] = value.to_bool
  end

  def notify_order_review
    settings.fetch('notifications',{}).fetch('order_review', true)
  end
  def notify_order_review=(value)
    settings['notifications'] ||= {}
    settings['notifications']['order_review'] = value.to_bool
  end

  def notify_discontinued_product
    settings.fetch('notifications',{}).fetch('discontinued_product', true)
  end
  def notify_discontinued_product=(value)
    settings['notifications'] ||= {}
    settings['notifications']['discontinued_product'] = value.to_bool
  end
  def notify_low_stock
    settings.fetch('notifications',{}).fetch('low_stock', false)
  end
  def notify_low_stock=(value)
    settings['notifications'] ||= {}
    settings['notifications']['low_stock'] = value.to_bool
  end
  # END NOTIFICATION SETTINGS
end
