Sweet AMS as external testing
============================

Create/update dummy application
```ruby
rake test_app
```


Spree AMS
========

[![Build Status](https://travis-ci.org/hhff/spree_ams.svg)](https://travis-ci.org/hhff/spree_ams)
[![Dependency Status](https://gemnasium.com/hhff/spree_ams.svg)](https://gemnasium.com/hhff/spree_ams)

Spree AMS is a module namspaced under Spree's Api module, providing a Spree Application with a collection of routes that behave identically to the regular api routes, but instead respond with serialized models (via the [Active Model Serializers](https://github.com/rails-api/active_model_serializers) gem).

This gem does not modify Spree's existing API - it can be used alongside this gem.


Installation
------------

Add spree_ams to your Spree store's Gemfile:

```ruby
gem 'spree_ams', :github => 'hhff/spree_ams', :branch => '3-0-alpha'
```

If you'd like to explicitly set the host URL for the Image Serializer to output absolute URLs  you'll need to set a config.action_controller.asset_host in your Rails environment configuration.

i.e. for your `development` environment in `config/environments/development.rb` set

```
config.action_controller.asset_host = 'http://localhost:3000'
```

If you're using S3, Paperclip will take care of this for you.

Install the Initializer:


```ruby
rails g spree:api:ams:install
```

Then run ```bundle``` and you're good to go!


Testing
-------

First bundle your dependencies, then run `rake`. `rake` will default to building the dummy app if it does not exist, then it will run specs. The dummy app can be regenerated by using `rake test_app`.

```shell
bundle
bundle exec rake
```

Contributing
------------

Generate docs from the Acceptance Tests (you'll need to generate your dummy test_app first)!

```ruby
rake app:docs:generate
```

Copyright (c) 2014 Hugh Francis, released under the New BSD License
