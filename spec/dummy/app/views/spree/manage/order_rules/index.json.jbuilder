json.array!(@spree_order_rules) do |spree_order_rule|
  json.extract! spree_order_rule, :id, :vendor_id, :name
  json.url spree_order_rule_url(spree_order_rule, format: :json)
end
