Devise.secret_key = "49c9ebdb0b39a68ab8f382695cb457f8bf05f1b03170abefb5ea8e2b2e665e521a0ca2ea80360b0ba5053bec8b3231cbced7"

Devise.setup do |config|
  config.stretches = Rails.env.test? ? 1 : 10
end
