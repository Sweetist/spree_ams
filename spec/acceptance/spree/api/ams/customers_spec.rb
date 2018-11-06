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

  before do
    header 'X-Token', token
    allow_any_instance_of(Spree::Api::Ams::CustomersController)
      .to receive(:authorize!)
  end

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

  post url + 'customers' do
    with_options scope: :customer do
      parameter :email, required: true
      parameter :name, required: true
    end
    let(:email) { 'email@test.com' }
    let(:name) { 'customer name' }
    let(:raw_post) { params.to_json }
    example_request 'Create' do
      expect(status).to eq(201)
    end
  end

  patch url + 'customers/:id' do
    let(:id) { customer.id }
    with_options scope: :customer do
      parameter :email
    end
    let(:email) { 'new_email@test.com' }
    let(:raw_post) { params.to_json }
    example_request 'Update' do
      expect(status).to eq(200)
    end
  end

  delete url + 'customers/:id' do
    let(:id) { customer.id }
    let(:raw_post) { params.to_json }
    example_request 'Delete' do
      expect(status).to eq(204)
    end
  end
end
