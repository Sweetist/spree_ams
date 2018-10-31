resource 'Customers' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  parameter :token, 'Authentication Token', required: true

  let!(:user) do
    user = create(:vendor_user)
    user.permission_order_basic_options = 2
    user.generate_spree_api_key!
    user.save
    user
  end

  let(:token) { user.spree_api_key }
  let!(:vendor) { user.company }
  let!(:customer) { create(:account, vendor: vendor) }

  get url + 'customers' do
    parameter :q, 'Ransack query parameter'

    example_request 'Get all customers' do
      expect(response_status).to equal(200)
    end
  end

  get url + 'customers/:id' do
    let(:id) { customer.id }

    example_request 'Getting a specific customer' do
      expect(status).to eq(200)
    end
  end

end
