# resource 'Variants' do
#   header 'Accept', 'application/json'
#   header 'Content-Type', 'application/json'
#   parameter :token, 'Authentication Token', required: true

#   let!(:user) do
#     user = create(:vendor_user)
#     user.permission_order_basic_options = 2
#     user.generate_spree_api_key!
#     user.save
#     user
#   end

#   let!(:token) { user.spree_api_key }
#   let!(:vendor) { user.company }
#   let!(:variant) { create(:variant, vendor: vendor) }

#   before do
#     header 'X-Token', token
#   end

#   delete url + 'variants/:id' do
#     let(:id) { variant.id }
#     let(:raw_post) { params.to_json }
#     example_request 'Delete' do
#       expect(response_status).to equal(204)
#     end
#   end

#   patch url + 'variants/:id' do
#     with_options scope: :variant do
#       parameter :name
#       parameter :price
#       parameter :sku
#       parameter :shipping_category_id
#     end
#     let(:id) { variant.id }
#     let(:name) { 'test name updated' }

#     let(:raw_post) { params.to_json }
#     example_request 'Update' do
#       expect(response_status).to equal(200)
#     end
#   end

#   post url + 'variants' do
#     with_options scope: :variant do
#       parameter :name, required: true
#       parameter :price, required: true
#       parameter :sku, required: true
#       parameter :shipping_category_id, required: true
#     end

#     let(:name) { 'test name' }
#     let(:price) { 20 }
#     let(:sku) { 'sku' }
#     let(:shipping_category_id) { 1 }

#     let(:raw_post) { params.to_json }
#     example_request 'Create' do
#       expect(response_status).to equal(201)
#     end
#   end

#   get url + 'variants' do
#     parameter :q, 'Ransack query parameter'

#     example_request 'Get variants' do
#       explanation 'The searching API is provided through the Ransack gem which Sweet depends on. The name_cont here is called a predicate, and you can learn more about them by reading about Predicates on the Ransack (wiki)[https://github.com/activerecord-hackery/ransack/wiki/Basic-Searching].'
#       expect(response_status).to equal(200)
#     end
#   end

#   get url + 'variants/:id' do
#     let(:id) { variant.id }

#     example_request 'Getting a specific variant' do
#       expect(status).to eq(200)
#     end
#   end
# end
