# == Schema Information
#
# Table name: spree_standing_order_trackers
#
#  id                :integer          not null, primary key
#  standing_order_id :integer
#  original          :json
#  original_changes  :json
#  active            :boolean
#  tracking_since    :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class Spree::StandingOrderTracker < ActiveRecord::Base
  belongs_to :standing_order, class_name: 'Spree::StandingOrder', foreign_key: :standing_order_id, primary_key: :id

  attr_default :active, true

  def stop_tracking!
    self.original_changes = self.summarize_changes
    self.active = false
    self.save
    if !self.original_changes["standing_order"].empty? or !self.original_changes["standing_line_items"]["new"].empty? || !self.original_changes["standing_line_items"]["updated"].empty? || !self.original_changes["standing_line_items"]["removed"].empty?
      self.notify!
    end
  end

  def notify!
    Spree::StandingOrderMailer.so_update_email(self.id).deliver_now # we can do deliver_now because we call stop_tracking! from background job
  end

  def summarize_changes
    so_o = Spree::StandingOrder.new(self.original["standing_order"])
    sli_os = self.original["standing_line_items"]
    so_c = self.standing_order
    so_changes = []
    sli_changes = {
      new: [],
      updated: [],
      removed: []
    }

    so_changes << { title: "Vendor", original: so_o.vendor.try(:name), current: so_c.vendor.try(:name) } if so_o.vendor_id != so_c.vendor_id
    so_changes << { title: "Customer", original: so_o.customer.try(:name), current: so_c.customer.try(:name) } if so_o.customer_id != so_c.customer_id
    so_changes << { title: "User", original: so_o.user.try(:name), current: so_c.user.try(:name) } if so_o.user_id != so_c.user_id
    so_changes << { title: "Name", original: so_o.name, current: so_c.name } if so_o.name != so_c.name
    so_changes << { title: "Start", original: DateHelper.sweet_date(so_o.start_at, so_o.vendor.try(:zone)), current: DateHelper.sweet_date(so_c.start_at, so_c.vendor.try(:zone)) } if so_o.start_at != so_c.start_at
    so_changes << { title: "End", original: so_o.end_string, current: so_c.end_string } if so_o.end_at_id != so_c.end_at_id
    so_changes << { title: "Frequency", original: so_o.frequency_string, current: so_c.frequency_string } if so_o.frequency_id != so_c.frequency_id || so_o.frequency_data_3_type != so_c.frequency_data_3_type
    so_changes << { title: "Action", original: so_o.timing_string, current: so_c.timing_string } if so_o.timing_id != so_c.timing_id || so_o.timing_process != so_c.timing_process

    sli_os.each do |sli_o|
      sli_c = so_c.standing_line_items.where(id: sli_o["id"]).first
      if sli_c && sli_c.quantity != sli_o["quantity"]
        sli_changes[:updated] << {variant_id: sli_o["variant_id"], original: sli_o["quantity"], current: sli_c.quantity}
      elsif !sli_c
        sli_changes[:removed] << {variant_id: sli_o["variant_id"], original: sli_o["quantity"]}
      end
    end
    sli_os_existing = sli_os.map{|sli| sli["variant_id"]}
    so_c.standing_line_items.where("variant_id NOT IN (?)", sli_os_existing).each do |sli_c|
      sli_changes[:new] << {variant_id: sli_c.variant_id, current: sli_c.quantity}
    end

    {
      standing_order: so_changes,
      standing_line_items: sli_changes
    }
  end

end
