object @customer

attributes *customer_attributes

child(:ship_address => :ship_address) do
  extends "spree/api/v1/addresses/show"
end
