# Set up liquid snippets / partials folder path
template_path = Rails.root.join('app/views/mailers/spree/shared')
Liquid::Template.file_system = Liquid::LocalFileSystem.new(template_path)
