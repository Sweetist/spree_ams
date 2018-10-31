resource 'Orders' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let!(:user) do
    user = create(:vendor_user)
    user.permission_order_basic_options = 2
    user.generate_spree_api_key!
    user.save
    user
  end

  let!(:vendor) { user.company }
  let!(:customer) { create(:company) }
  let!(:customer_user) { create(:customer_user, company: customer) }
  let!(:account) { create(:account, customer: customer, vendor: vendor) }
  let!(:order) { create(:order_with_line_items, vendor: user.company, account: account)}
  # let(:orde2) { create(:order_with_line_items, vendor: user.company, account: account)}


  parameter :token, 'Authentication Token', required: true
  let(:token) { user.spree_api_key }
  # authentication :apiKey, :token, description: 'Private key for API access'
  # header 'X-Spree-Token', token

  # before do
  #   binding.pry
  #   allow(Spree::Api::Ams::OrdersController).to receive(:authorize!)
  # end

  get url + 'orders' do
    parameter :q, 'Query parameter'
    example_request 'Get all orders' do
      expect(response_status).to equal(200)
    end
  end

  get url + 'orders/:id' do
    let(:id) { order.id }

    example_request 'Getting a specific order' do
      expect(status).to eq(200)
    end
  end

  put url + 'orders/:id/cancel' do
    let(:id) { order.id }
    let(:raw_post) { params.to_json }

    before do
      order.next
    end
    example_request 'Cancel Order' do
      expect(status).to eq(200)
    end
  end

  put url + 'orders/:id' do
    with_options scope: :order do
      parameter :email, type: :string
    end
    let(:id) { order.id }
    let(:email) { 'test@example.com' }

    let(:raw_post) { params.to_json }
    example_request 'Update order' do
      expect(status).to eq(200)
    end
  end

  post url + 'orders' do
    with_options scope: :order do
      parameter :account_id, required: true
      parameter :due_date, required: true
      parameter :delivery_date, required: true
      parameter :shipping_address_id
      parameter :billing_address_id
    end

    parameter :line_items, type: :array, scope: :order, required: true
    with_options scope: :line_items do
      parameter :variant_id, type: :integer, required: true
      parameter :quantity, type: :integer, required: true
    end

    let(:variant) { create(:variant) }
    let(:account_id) { account.id }
    let(:due_date) { Date.current }
    let(:delivery_date) { Date.current }
    let!(:line_items) do
      [{ variant_id: variant.to_param, quantity: '5' }]
    end

    let(:raw_post) { params.to_json }

    example 'Create an order' do
      # binding.pry
      do_request
      expect(status).to eq(201)
    end
  end
end
