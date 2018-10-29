require 'generators/spree/install/install_generator'
require 'generators/spree/dummy/dummy_generator'
Spree::DummyGenerator.class_eval do
  def test_dummy_clean
    puts 'SWEEET EXTEND DUMMY'
    inside dummy_path do
      remove_file ".gitignore"
      remove_file "doc"
      # remove_file "Gemfile"
      remove_file "lib/tasks"
      remove_file "app/assets/images/rails.png"
      remove_file "app/assets/javascripts/application.js"
      remove_file "public/index.html"
      remove_file "public/robots.txt"
      remove_file "README"
      remove_file "test"
      remove_file "vendor"
      remove_file "spec"
    end
  end
end
