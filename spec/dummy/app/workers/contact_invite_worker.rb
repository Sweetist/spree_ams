class ContactInviteWorker
  include Sidekiq::Worker

  def perform(vendor_id, all_contacts = false, contact_ids = [])
    @vendor = Spree::Company.find(vendor_id)
    if all_contacts
      @vendor.contacts.find_each do |contact|
        if contact.valid_emails.present? && contact.account_ids.any?
          Spree::ContactMailer.invite_email(@vendor, contact).deliver_later
        end
      end
    else
      @vendor.contacts.where(id: contact_ids).each do |contact|
        if contact.valid_emails.present? && contact.account_ids.any?
          Spree::ContactMailer.invite_email(@vendor, contact).deliver_later
        end
      end
    end
  end

end
