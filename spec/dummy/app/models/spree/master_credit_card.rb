# module Spree
#   class MasterCreditCard < Spree::Base
#       # belongs_to :user, class_name: Spree.user_class, foreign_key: 'user_id'
#       belongs_to :company, class_name: 'Spree::Company', foreign_key: :company_id, primary_key: :id
#       has_many :credit_cards #, dependent: :destroy
#
#       before_save :set_last_digits
#       before_save :set_card_type
#       after_save :ensure_one_default, :create_credit_card
#
#       attr_accessor :encrypted_data,
#                     :number,
#                     :imported,
#                     :verification_value
#
#       validates :month, :year, numericality: { only_integer: true }, if: :require_card_numbers?, on: :create
#       validates :number, presence: true, if: :require_card_numbers?, on: :create, unless: :imported
#       validates :name, presence: true, if: :require_card_numbers?, on: :create
#       validates :verification_value, presence: true, if: :require_card_numbers?, on: :create, unless: :imported
#       validates :last_digits, uniqueness: {scope: [:company_id, :verification_value]}
#
#       scope :with_payment_profile, -> { where('gateway_customer_profile_id IS NOT NULL') }
#       scope :default, -> { where(default: true) }
#
#       # needed for some of the ActiveMerchant gateways (eg. SagePay)
#       alias_attribute :brand, :cc_type
#
#       # ActiveMerchant::Billing::CreditCard added this accessor used by some gateways.
#       # More info: https://github.com/spree/spree/issues/6209
#       #
#       # Returns or sets the track data for the card
#       #
#       # @return [String]
#       attr_accessor :track_data
#
#       CARD_TYPES = {
#         visa: /^4\d{12}(\d{3})?(\d{3})?$/,
#         master: /^(5[1-5]\d{4}|677189|222[1-9]\d{2}|22[3-9]\d{3}|2[3-6]\d{4}|27[01]\d{3}|2720\d{2})\d{10}$/,
#         discover: /^(6011|65\d{2}|64[4-9]\d)\d{12}|(62\d{14})$/,
#         american_express: /^3[47]\d{13}$/,
#         diners_club: /^3(0[0-5]|[68]\d)\d{11}$/,
#         jcb: /^35(28|29|[3-8]\d)\d{12}$/,
#         switch: /^6759\d{12}(\d{2,3})?$/,
#         solo: /^6767\d{12}(\d{2,3})?$/,
#         dankort: /^5019\d{12}$/,
#         maestro: /^(5[06-8]|6\d)\d{10,17}$/,
#         forbrugsforeningen: /^600722\d{10}$/,
#         laser: /^(6304|6706|6709|6771(?!89))\d{8}(\d{4}|\d{6,7})?$/
#       }
#
#       # As of rails 4.2 string columns always return strings, perhaps we should
#       # change these to integer columns on db level
#       def month
#         if type_casted = super
#           type_casted.to_i
#         end
#       end
#
#       def year
#         if type_casted = super
#           type_casted.to_i
#         end
#       end
#
#       def expiry=(expiry)
#         return unless expiry.present?
#         self[:month], self[:year] =
#         if expiry.match(/\d{2}\s?\/\s?\d{2,4}/) # will match mm/yy and mm / yyyy
#           expiry.delete(' ').split('/')
#         elsif match = expiry.match(/(\d{2})(\d{2,4})/) # will match mmyy and mmyyyy
#           [match[1], match[2]]
#         end
#         if self[:year]
#           self[:year] = "20" + self[:year] if self[:year].length == 2
#           self[:year] = self[:year].to_i
#         end
#         self[:month] = self[:month].to_i if self[:month]
#       end
#
#       def number=(num)
#         @number = num.gsub(/[^0-9]/, '') rescue nil
#       end
#
#       # cc_type is set by jquery.payment, which helpfully provides different
#       # types from Active Merchant. Converting them is necessary.
#       # def cc_type=(type)
#       #   self[:cc_type] = case type
#       #   when 'mastercard', 'maestro' then 'master'
#       #   when 'amex' then 'american_express'
#       #   when 'dinersclub' then 'diners_club'
#       #   when '' then try_type_from_number
#       #   else type
#       #   end
#       # end
#
#       def set_card_type
#         length = number.size
#         if length == 15 && number =~ /^(34|37)/
#           self[:cc_type] = "AMEX"
#         elsif length == 16 && number =~ /^6011/
#           self[:cc_type] = "Discover"
#         elsif length == 16 && number =~ /^5[1-5]/
#           self[:cc_type] = "MasterCard"
#         elsif (length == 13 || length == 16) && number =~ /^4/
#           self[:cc_type] = "Visa"
#         else
#           self[:cc_type] = nil
#         end
#         # debugger
#       end
#
#       def set_last_digits
#         number.to_s.gsub!(/\s/,'')
#         verification_value.to_s.gsub!(/\s/,'')
#         self.last_digits ||= number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1)
#       end
#
#       def try_type_from_number
#         numbers = number.delete(' ') if number
#         CARD_TYPES.find{|type, pattern| return type.to_s if numbers =~ pattern}.to_s
#       end
#
#       def verification_value?
#         verification_value.present?
#       end
#
#       # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
#       def display_number
#         "XXXX-XXXX-XXXX-#{last_digits}"
#       end
#
#       def actions
#         %w{capture void credit}
#       end
#
#       # Indicates whether its possible to capture the payment
#       def can_capture?(payment)
#         payment.pending? || payment.checkout?
#       end
#
#       # Indicates whether its possible to void the payment.
#       def can_void?(payment)
#         !payment.failed? && !payment.void?
#       end
#
#       # Indicates whether its possible to credit the payment.  Note that most gateways require that the
#       # payment be settled first which generally happens within 12-24 hours of the transaction.
#       def can_credit?(payment)
#         payment.completed? && payment.credit_allowed > 0
#       end
#
#       def has_payment_profile?
#         gateway_customer_profile_id.present? || gateway_payment_profile_id.present?
#       end
#
#       # ActiveMerchant needs first_name/last_name because we pass it a Spree::CreditCard and it calls those methods on it.
#       # Looking at the ActiveMerchant source code we should probably be calling #to_active_merchant before passing
#       # the object to ActiveMerchant but this should do for now.
#       def first_name
#         name.to_s.split(/[[:space:]]/, 2)[0]
#       end
#
#       def last_name
#         name.to_s.split(/[[:space:]]/, 2)[1]
#       end
#
#       private
#
#       def require_card_numbers?
#         !self.encrypted_data.present? && !self.has_payment_profile?
#       end
#
#       def ensure_one_default
#         # debugger
#
#         # if self.user_id && self.default
#         #   CreditCard.where(default: true).where.not(id: self.id).where(user_id: self.user_id).each do |ucc|
#         #     ucc.update_columns(default: false)
#         #   end
#         # end
#       end
#
#       def create_credit_card
#         company = self.company
#         # check for all vendors
#         company.vendor_payment_methods.each do |payment|
#           if payment.type == "Spree::Gateway::StripeGateway"
#             creditCard = Spree::CreditCard.create(
#               month: self.month,
#               year: self.year,
#               cc_type: self.cc_type,
#               number: "000000000000"+self.last_digits,
#               name: self.name,
#               payment_method_id: payment.id,
#               master_credit_card_id: self.id,
#               company_id: company.id,
#               user_id: 1,
#               verification_value: self.verification_value
#             )
#           end
#         end
#       end
#
#   end
# end
