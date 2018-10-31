Spree::Promotion.class_eval do
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  validate :can_use_hidden_discount

  attr_accessor :update_prices
  after_save :determine_should_update_prices
  after_commit :update_viewable_variant_prices, on: [:create, :update], if: :should_update_prices
  after_commit :remove_viewable_variant_prices, on: [:destroy], if: :should_update_prices
  # Ransack arguments from Spree here for reference only.  Do not uncomment or override.
  # To add additional properties use +=
  #
  # self.whitelisted_ransackable_attributes = ['path', 'promotion_category_id', 'code']
  self.whitelisted_ransackable_attributes += %w{name active? customer_name price_type_shown action_type}
  self.whitelisted_ransackable_associations = %w{promotion_category}

  def account_fully_qualified_name
    accounts = self.accounts
    if accounts.empty?
      'All'
    elsif accounts.count == 1
      accounts.first.fully_qualified_name
    else
      'Multiple Accounts'
    end
  end

  def product_name
    product_ids = self.product_ids
    products_count = product_ids.count
    if products_count == 0
      'None'
    elsif products.count == 1
      Spree::Product.find_by_id(product_ids.first).try(:name)
    elsif products_count < self.vendor.products.count
      'Multiple Products'
    else
      'All'
    end
  end

  def product_ids
    p1 = rules.where(type: "Spree::Promotion::Rules::Product").map(&:product_ids).flatten
    p2 = Spree::Variant.joins(:product)
    .where('spree_products.vendor_id = ? AND spree_variants.id IN (?)', self.vendor_id, self.variant_ids).group('spree_products.id')
    .pluck('spree_products.id')
    p3 = Spree::Classification.joins(:product).where('spree_products_taxons.taxon_id IN (?) AND spree_products.vendor_id = ?', self.taxon_ids, self.vendor_id)
    .pluck('spree_products_taxons.product_id')
    (p1 + p2 + p3).uniq
  end

  def variants
    rules.where(type: "Spree::Promotion::Rules::Variant").map(&:variants).flatten.uniq
  end

  def variant_ids
    rules.where(type: "Spree::Promotion::Rules::Variant").map(&:variant_ids).flatten.uniq
  end

  def accounts
    rules.where(type: "Spree::Promotion::Rules::Account").map(&:accounts).flatten.uniq
  end

  def account_ids
    rules.where(type: "Spree::Promotion::Rules::Account").map(&:account_ids).flatten.uniq
  end

  def taxons
    rules.where(type: "Spree::Promotion::Rules::Taxon").map(&:taxons).flatten.uniq
  end

  def taxon_ids
    rules.where(type: "Spree::Promotion::Rules::Taxon").map(&:taxon_ids).flatten.uniq
  end

  def price_type_shown
    self.advertise ? 'Base' : 'Discounted'
  end

  def action_type
    action = self.promotion_actions.first
    if action.blank? || action.type.blank?
      ""
    else
      action.type.split('::').last.underscore.humanize
    end
  end

  def self.unadvertised
    where(advertise: false)
  end

  def active?
    Spree::Promotion.active.include?(self)
  end

  def eligible?(promotable)
    if promotable.class.to_s == "Spree::Order"
      vendor_id = promotable.vendor_id
    else
      vendor_id = promotable.order.vendor_id
    end

    return false if expired? || usage_limit_exceeded?(promotable) || blacklisted?(promotable) || self.vendor_id != vendor_id
    !!eligible_rules(promotable, {})
  end

  def update_promo_rules(rules)
    rules ||= []
    promo_rules = []
    Spree::PromotionRule.where(promotion_id: nil).destroy_all #clean up any saved rules during failed create
    rules.each do |type, attrs|
      type_name = type.split("_").map{|word| word.capitalize}.join("")
      rule = self.rules.find_or_initialize_by(type: "Spree::Promotion::Rules::#{type_name}")
      case type
      when "account"
        if rules[type][:account_ids].first.empty?
          rule.destroy
        else
          rule.account_ids = rules.fetch(type, {}).fetch(:account_ids, ['']).first.split(',')
          promo_rules << rule
        end
      when "product"
        if rules[type][:product_ids].first.empty?
          rule.destroy
        else
          rule.product_ids = rules.fetch(type, {}).fetch(:product_ids, ['']).first.split(',')
          rule.update(preferences: {match_policy: rules[type][:match_policy]})
          promo_rules << rule
        end
      when "variant"
        if rules[type][:variant_ids].first.empty?
          rule.destroy
        else
          rule.variant_ids = rules.fetch(type, {}).fetch(:variant_ids, ['']).first.split(',')
          rule.update(preferences: {match_policy: rules[type][:match_policy]})
          promo_rules << rule
        end
      when "taxon"
        if rules[type][:taxon_ids].first.empty?
          rule.destroy
        else
          rule.taxon_ids = rules.fetch(type, {}).fetch(:taxon_ids, ['']).first.split(',')
          rule.update(preferences: {match_policy: rules[type][:match_policy]})
          promo_rules << rule
        end
      when "first_order"
        if rules[type] == "false"
          rule.destroy
        else
          promo_rules << rule
        end
      when "item_total"
        if rules[type][:amount_min].empty? && rules[type][:amount_max].empty?
          rule.destroy
        else
          rules[type][:amount_min] = 0 if rules[type][:amount_min].empty?
          rules[type][:amount_max] = 0 if rules[type][:amount_max].empty?
          rule.update(preferences: {amount_min: BigDecimal.new(rules[type][:amount_min]),
                              operator_min: rules[type][:operator_min],
                              amount_max: BigDecimal.new(rules[type][:amount_max]),
                              operator_max: rules[type][:operator_max]})
          promo_rules << rule
        end
      end
    end

    promo_rules
  end

  def update_promo_action(actions)
    actions ||= []
    self.actions.each do |action|
      action.destroy! unless action.type == actions[:type]
    end

    action = self.actions.where('deleted_at IS NULL').empty? ? self.actions.new(type: actions[:type]) : self.actions.last

    case action.type
    when "Spree::Promotion::Actions::CreateItemAdjustments"
      action = update_create_item_adjustments(actions, action)
    when "Spree::Promotion::Actions::CreateAdjustment"
      action = update_create_order_adjustment(actions, action)
    when "Spree::Promotion::Actions::CreateLineItems"
      action = update_create_line_items(actions, action)
    when "Spree::Promotion::Actions::FreeShipping"
      # action = update_free_shipping(actions, action)
    end

    [action]
  end

  def update_create_order_adjustment(preferences, action)

    if !preferences[:flat_order_percent].blank?
      if action.calculator.blank?
        action.build_calculator(type: "Spree::Calculator::FlatPercentItemTotal",
           preferences: {flat_percent: BigDecimal.new(preferences[:flat_order_percent])}
          )
      elsif action.calculator.type == "Spree::Calculator::FlatPercentItemTotal"
        action.calculator.update(preferences: {flat_percent: BigDecimal.new(preferences[:flat_order_percent])})
      else
        action.calculator.destroy!
        action.build_calculator(type: "Spree::Calculator::FlatPercentItemTotal",
           preferences: {flat_percent: BigDecimal.new(preferences[:flat_order_percent])}
          )
      end
    elsif !preferences[:flat_order_amount].blank?
      if action.calculator.blank?
        action.build_calculator(type: "Spree::Calculator::FlatRate",
           preferences: {amount: BigDecimal.new(preferences[:flat_order_amount]),
             currency: preferences[:flat_order_amount_currency].empty? ? 'USD' : preferences[:flat_order_amount_currency]
            }
          )
      elsif action.calculator.type == "Spree::Calculator::FlatRate"
        action.calculator.update(preferences: {amount: BigDecimal.new(preferences[:flat_order_amount]),
             currency: preferences[:flat_order_amount_currency].empty? ? 'USD' : preferences[:flat_order_amount_currency]
            }
          )
      else
        c = action.calculator
        c.destroy!
        action.build_calculator(type: "Spree::Calculator::FlatRate",
           preferences: {amount: BigDecimal.new(preferences[:flat_order_amount]),
             currency: preferences[:flat_order_amount_currency].empty? ? 'USD' : preferences[:flat_order_amount_currency]
            }
          )
      end
    elsif !(preferences[:flex_order_first_item].blank? || preferences[:flex_order_additional_item].blank? || preferences[:flex_order_max_items].blank?)
      if action.calculator.blank?
        action.build_calculator(type: "Spree::Calculator::FlexiRate",
           preferences: {first_item: BigDecimal.new(preferences[:flex_order_first_item]),
             additional_item: BigDecimal.new(preferences[:flex_order_additional_item]),
             max_items: preferences[:flex_order_max_items],
             currency: preferences[:flex_order_currency].empty? ? 'USD' : preferences[:flex_order_currency]
            }
          )
      elsif action.calculator.type == "Spree::Calculator::FlexiRate"
        action.calculator.update(preferences: {first_item: BigDecimal.new(preferences[:flex_order_first_item]),
              additional_item: BigDecimal.new(preferences[:flex_order_additional_item]),
              max_items: preferences[:flex_order_max_items],
              currency: preferences[:flex_order_currency].empty? ? 'USD' : preferences[:flex_order_currency]
            }
          )
      else
        action.calculator.destroy!
        action.build_calculator(type: "Spree::Calculator::FlexiRate",
            preferences: {first_item: BigDecimal.new(preferences[:flex_order_first_item]),
              additional_item: BigDecimal.new(preferences[:flex_order_additional_item]),
              max_items: preferences[:flex_order_max_items],
              currency: preferences[:flex_order_currency].empty? ? 'USD' : preferences[:flex_order_currency]
            }
          )
      end
    end

    action
  end

  def update_create_item_adjustments(preferences, action)
    if !preferences[:percent_on_line_item].blank?
      if action.calculator.blank?
        action.build_calculator(type: "Spree::Calculator::PercentOnLineItem",
           preferences: {percent: BigDecimal.new(preferences[:percent_on_line_item])}
          )
      elsif action.calculator.type == "Spree::Calculator::PercentOnLineItem"
        action.calculator.update(preferences: {percent: BigDecimal.new(preferences[:percent_on_line_item])})
      else
        action.calculator.destroy!
        action.build_calculator(type: "Spree::Calculator::PercentOnLineItem",
           preferences: {percent: BigDecimal.new(preferences[:percent_on_line_item])}
          )
      end
    elsif !preferences[:flat_amount].blank?
      if action.calculator.blank?
        action.build_calculator(type: "Spree::Calculator::FlatRate",
           preferences: {amount: BigDecimal.new(preferences[:flat_amount]),
             currency: preferences[:flat_currency].empty? ? 'USD' : preferences[:flat_currency]
            }
          )
      elsif action.calculator.type == "Spree::Calculator::FlatRate"
        action.calculator.update(preferences: {amount: BigDecimal.new(preferences[:flat_amount]),
             currency: preferences[:flat_currency].empty? ? 'USD' : preferences[:flat_currency]
            }
          )
      else
        action.calculator.destroy!
        action.build_calculator(type: "Spree::Calculator::FlatRate",
           preferences: {amount: BigDecimal.new(preferences[:flat_amount]),
             currency: preferences[:flat_currency].empty? ? 'USD' : preferences[:flat_currency]
            }
          )
      end
    elsif !(preferences[:flex_first_item].blank? || preferences[:flex_additional_item].blank? || preferences[:flex_max_items].blank?)
      if action.calculator.blank?
        action.build_calculator(type: "Spree::Calculator::FlexiRate",
           preferences: {first_item: BigDecimal.new(preferences[:flex_first_item]),
             additional_item: BigDecimal.new(preferences[:flex_additional_item]),
             max_items: preferences[:flex_max_items],
             currency: preferences[:flex_currency].empty? ? 'USD' : preferences[:flex_currency]
            }
          )
      elsif action.calculator.type == "Spree::Calculator::FlexiRate"
        action.calculator.update(preferences: {first_item: BigDecimal.new(preferences[:flex_first_item]),
              additional_item: BigDecimal.new(preferences[:flex_additional_item]),
              max_items: preferences[:flex_max_items],
              currency: preferences[:flex_currency].empty? ? 'USD' : preferences[:flex_currency]
            }
          )
      else
        action.calculator.destroy!
        action.build_calculator(type: "Spree::Calculator::FlexiRate",
            preferences: {first_item: BigDecimal.new(preferences[:flex_first_item]),
              additional_item: BigDecimal.new(preferences[:flex_additional_item]),
              max_items: preferences[:flex_max_items],
              currency: preferences[:flex_currency].empty? ? 'USD' : preferences[:flex_currency]
            }
          )
      end
    end

    action
  end

  def is_eligible_discount?(account, product, variant)
    eligibility_errors = [];

    self.rules.each do |rule|
      case rule.type
      when "Spree::Promotion::Rules::Account"
        unless account.blank? || account && rule.account_ids.include?(account.id)
          eligibility_errors.push('no applicable accounts')
        else
          return true if self.match_policy == 'any'
        end

      when "Spree::Promotion::Rules::Product"
        unless product && rule.product_ids.include?(product.id)
          eligibility_errors.push('no applicable products')
        else
          return true if self.match_policy == 'any'
        end
      when "Spree::Promotion::Rules::Variant"
        unless variant && rule.variant_ids.include?(variant.id)
          eligibility_errors.push('no applicable variants')
        else
          return true if self.match_policy == 'any'
        end
      when "Spree::Promotion::Rules::Taxon"
        unless product && (rule.match_item_taxons?(product) || rule.match_item_taxons?(variant))
          eligibility_errors.push('no applicable taxons')
        else
          return true if self.match_policy == 'any'
        end
      else
          eligibility_errors.push('should be advertised')
      end
    end

    eligibility_errors.empty?
  end

  def update_viewable_variant_prices
    Sidekiq::Client.push('class' => CacheDiscountedPricesWorker, 'queue' => 'critical', 'args' => [self.vendor_id, self.id, 'update'])
  end

  def remove_viewable_variant_prices
    Sidekiq::Client.push('class' => CacheDiscountedPricesWorker, 'queue' => 'critical', 'args' => [self.vendor_id, self.id, 'delete'])
  end

  def eligible_product_ids
    self.vendor.products.includes(:variants_including_master).select{|product| product.variants_including_master.any?{|variant| self.is_eligible_discount?(nil, product, variant)}}.map{|product| product.id.to_s}
  end

  def eligible_variant_ids
    self.vendor.variants_including_master.select{|variant| self.is_eligible_discount?(nil, variant.product, variant) }.map{ |variant| variant.id.to_s }
  end

  def eligible_account_ids
    if self.rules.any?{|rule| rule.type == "Spree::Promotion::Rules::Account"}
      self.account_ids
    else
      self.vendor.customer_account_ids
    end
  end


  def activate(payload)
    order = payload[:order]
    return unless self.class.order_activatable?(order)

    payload[:promotion] = self

    # Track results from actions to see if any action has been taken.
    # Actions should return nil/false if no action has been taken.
    # If an action returns true, then an action has been taken.
    results = actions.map do |action|
      action.perform(payload)
    end
    # If an action has been taken, report back to whatever activated this promotion.
    action_taken = results.include?(true)

    if action_taken
    # connect to the order
    # create the join_table entry.
      order.promotions << self
    end

    action_taken
  end

  private

  def blacklisted?(promotable)
    case promotable
    when Spree::LineItem
      !promotable.product.promotionable? || promotable.price != promotable.variant.price
    when Spree::Order
      promotable.line_items.any? &&
        !promotable.line_items.joins(:product).where(spree_products: {promotionable: true}).any?
    end
  end

  def determine_should_update_prices
    self.update_prices = advertise_changed? || !advertise
  end

  def should_update_prices
    self.update_prices || (destroyed? && !advertise)
  end

  def can_use_hidden_discount
    return true if advertise? || !vendor.try(:only_price_list_pricing)

    self.errors.add(:base, 'Showing discounted price is not supported when using price lists.')
    false
  end

end
