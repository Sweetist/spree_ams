class CustomerInviteWorker
  include Sidekiq::Worker

  def perform(vendor_id, all_customers = false, account_ids = [])
    vendor = Spree::Company.find(vendor_id)
    if all_customers
      vendor.customer_accounts.includes(:customer).find_each do |account|
        invite_customer_contacts(vendor_id, account)
      end
    else
      vendor.customer_accounts.where(id: account_ids).includes(:customer).find_each do |account|
        invite_customer_contacts(vendor_id, account)
      end
    end
  end

  def invite_customer_contacts(vendor_id, account)
    contacts = []
    @vendor = Spree::Company.find_by_id(vendor_id)

    if account.valid_emails.present?

      # unless there are no valid emails on the account,
      # let's go through each email address in the email field on the account,
      # create contacts for them, and then invite the contacts to use Sweet

      account.valid_emails.uniq.each do |email|
        contact = @vendor.contacts.find_by_email(email)
        if contact.nil?
          # no contacts on file for this email address, so let's create one
          contact = @vendor.contacts.new(email: email)
          if contact.save
            contact.account_ids = [account.id] # it's a new contact so we need to set up the account relationship
            Spree::ContactMailer.invite_email(@vendor, contact).deliver_later
          else
            # contact did not save
            # notify airbrake so we don't lose track of this
            Airbrake.notify(
              error_message: contact.errors.full_messages.to_sentence,
              error_class: "CustomerInviteWorker",
              parameters: {
                vendor: @vendor,
                account: account,
                contact_email: email,
                contact: contact
              }
            )

          end

        elsif contact.invited_at.nil? || contact.invited_at < 15.minutes.ago

          Spree::ContactMailer.invite_email(@vendor, contact).deliver_later
        end
      end
    else
      # No emails on file (@account.valid_emails.empty? == true)
      return nil
    end
  end

end
