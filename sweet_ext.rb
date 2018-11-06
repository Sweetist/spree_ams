desc 'Generates a dummy Sweet app for testing'
namespace :sweet do
  task :test_app do
    ENV['LIB_NAME'] = 'spree_ams'
    nice_puts "SWEET app copy or update '#{dummy_path}' from '#{sweet_path}'"
    nice_puts 'Clear Dummy Path'
    remove_directory_if_exists(dummy_path)
    nice_puts 'Copy from SWEET source'
    copy_direcories(sweet_path, dummy_path)
    copy_files
    remove_gem_from_gemfile('spree_ams')
  end
end

def copy_direcories(from, to)
  create_dummy_dir
  dirs = ['app', 'config', 'db', 'lib', 'spec/factories']
  dirs.each do |dir|
    print_and_flush('.')
    FileUtils.copy_entry(from + "/#{dir}", to + "/#{dir}")
  end
end

def copy_files
  files = ['Gemfile', 'Gemfile.lock', 'config.ru', 'Rakefile']
  files.each do |file|
    FileUtils.cp(sweet_path + '/' + file, dummy_path)
  end
end

def remove_gem_from_gemfile(gem_name)
  file_lines = ''

  IO.readlines(dummy_path + '/Gemfile').each do |line|
    file_lines += line unless line.start_with? "gem '#{gem_name}'"
  end

  File.open(dummy_path + '/Gemfile', 'w') do |file|
    file.puts file_lines
  end
end

def print_and_flush(str)
  print str
  $stdout.flush
end

def create_dummy_dir
  FileUtils.mkdir_p(dummy_path)
  FileUtils.mkdir_p(dummy_path + '/spec')
end

def nice_puts(text)
  puts "... #{text} ..."
end

def dummy_path
  File.expand_path('spec/dummy', __dir__)
end

def sweet_path
  ENV['DUMMY_PATH'] || File.expand_path('../get-sweet', __dir__)
end

def remove_directory_if_exists(path)
  remove_dir(path) if File.directory?(path)
end
