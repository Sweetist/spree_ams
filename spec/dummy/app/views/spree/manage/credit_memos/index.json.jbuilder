json.array!(@spree_manage_credit_memos) do |spree_manage_credit_memo|
  json.extract! spree_manage_credit_memo, :id
  json.url spree_manage_credit_memo_url(spree_manage_credit_memo, format: :json)
end
