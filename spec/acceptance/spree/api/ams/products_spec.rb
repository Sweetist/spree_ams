resource 'Products' do
  # Seed Product
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
  let!(:product) { create(:product, vendor: vendor) }

  delete url + 'products/:id' do
    let(:id) { product.id }
    let(:raw_post) { params.to_json }
    example_request 'Delete product' do
      expect(response_status).to equal(204)
    end
  end

  put url + 'products/:id' do
    with_options scope: :product do
      parameter :name
      parameter :price
      parameter :sku
      parameter :shipping_category_id
    end
    let(:id) { product.id }
    let(:name) { 'test name updated' }

    let(:raw_post) { params.to_json }
    example_request 'Update product' do
      expect(response_status).to equal(200)
    end
  end

  post url + 'products' do
    with_options scope: :product do
      parameter :name, required: true
      parameter :price, required: true
      parameter :sku, required: true
      parameter :shipping_category_id, required: true
    end

    let(:name) { 'test name' }
    let(:price) { 20 }
    let(:sku) { 'sku' }
    let(:shipping_category_id) { 1 }

    let(:raw_post) { params.to_json }
    example_request 'Create product' do
      expect(response_status).to equal(201)
    end
  end

  get url + 'products' do
    parameter :q, 'Ransack query parameter'

    example_request 'Get all products' do
      expect(response_status).to equal(200)
    end
  end

  get url + 'products/:id' do
    let(:id) { product.id }

    example_request 'Getting a specific product' do
      expect(status).to eq(200)
    end
  end
end
