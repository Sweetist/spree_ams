Sweet AMS Documentation
=====================

Sweet AMS wraps the Spree API with the Active Model Serializers gem.

Overview
========
Sweet supports RESTful access to the following resources and their sub-resources: products, orders, accounts.

### JSON Data
Developers communicate with the Sweet API using the JSON data format. Requests for data are communicated in the standard manner using the HTTP protocol.

### Making an API Call
You will need an authentication token to access the API. These keys will be generated on your profile page. To make a request to the API, pass a X-Token header along with the request:
```bash
$ curl --header "X-Token: YOUR_KEY_HERE" http://example.com/api/v1/products.json
```

Alternatively, you may also pass through the token as a parameter in the request if a header just won’t suit your purposes (i.e. JavaScript console debugging).
```bash
$ curl http://example.com/api/v1/products.json?token=YOUR_KEY_HERE
```
The token allows the request to assume the same level of permissions as the actual user to whom the token belongs.
