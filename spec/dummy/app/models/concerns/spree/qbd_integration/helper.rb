module Spree::QbdIntegration::Helper
  def qbd_amt_type(num)
    sprintf('%.2f', num.to_d)
  end
end
