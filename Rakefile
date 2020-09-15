$LOAD_PATH << File.expand_path("./lib", __dir__)

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

# Autoloading
require 'zeitwerk'
loader = Zeitwerk::Loader.new
loader.push_dir("./lib")
loader.setup

require "rspec/core/rake_task"

require "active_record"
load "active_record/railties/databases.rake"

Dir.glob('lib/tasks/*.rake').each { |r| import r }

namespace :db do
  task :environment do
    require "topological_inventory/core/ar_helper"
    if File.exist?(Pathname.new(__dir__).join("config/database.yml"))
      TopologicalInventory::Core::ArHelper.database_yaml_path = Pathname.new(__dir__).join("config/database.yml")
    else
      ENV['DATABASE_URL'] ||= "postgresql://#{ENV['DATABASE_USER']}:#{ENV['DATABASE_PASSWORD']}@#{ENV['DATABASE_HOST']}:#{ENV['DATABASE_PORT']}/topological_inventory_production?encoding=utf8&pool=5&wait_timeout=5"
    end

    TopologicalInventory::Core::ArHelper.load_environment!
  end
  Rake::Task["db:load_config"].enhance(["db:environment"])
end

# Spec related rake tasks
RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  task :initialize do
    ENV["RAILS_ENV"] ||= "test"
  end

  desc "Setup the database for running tests"
  task :setup => [:initialize, "db:test:prepare"]
end

task default: :spec
