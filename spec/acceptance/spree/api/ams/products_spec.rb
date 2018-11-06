resource 'Products' do
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
  let!(:product) { create(:product, vendor: vendor, name: 'Sweet Product') }

  before do
    header 'X-Token', token
    allow_any_instance_of(Spree::Api::Ams::ProductsController)
      .to receive(:authorize!)
  end

  delete url + 'products/:id' do
    let(:id) { product.id }
    let(:raw_post) { params.to_json }
    example_request 'Delete' do
      expect(response_status).to equal(204)
    end
  end

  patch url + 'products/:id' do
    with_options scope: :product do
      parameter :name
      parameter :price
      parameter :sku
      parameter :shipping_category_id
    end
    let(:id) { product.id }
    let(:name) { 'test name updated' }

    let(:raw_post) { params.to_json }
    example_request 'Update' do
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
    example_request 'Create' do
      expect(response_status).to equal(201)
    end
  end

  get url + 'products' do
    context 'index' do
      example_request 'Index' do
        expect(response_status).to equal(200)
      end
    end
    context 'search' do
      parameter :q, 'Ransack query parameter'
      parameter :name_cont, 'Ransack predicator', scope: :q
      let(:name_cont) { product.name }
      explanation 'The searching API is provided through the Ransack gem which Sweet depends on. The name_cont here is called a predicate, and you can learn more about them by reading about Predicates on the Ransack (wiki)[https://github.com/activerecord-hackery/ransack/wiki/Basic-Searching].'
      example_request 'Search' do
        expect(response_status).to equal(200)
      end
    end
  end

  get url + 'products/:id' do
    let(:id) { product.id }

    example_request 'Getting a specific product' do
      expect(status).to eq(200)
    end
  end
end
