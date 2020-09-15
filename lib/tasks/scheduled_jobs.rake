require "rake"
require "optimist"

namespace :schedule do
  desc "Schedule Targeted Refresh"
  task :targeted_refresh => "db:environment" do
    TopologicalInventory::Scheduler::Worker.new(:host => args[:queue_host], :port => args[:queue_port]).run
  end

  desc "Schedule DB Cleanup"
  task :db_cleanup => "db:environment" do
    TopologicalInventory::Scheduler::DatabaseTools.new.remove_old_records
  end

  def args
    @args ||= parse_args.tap do |arguments|
      check_args(arguments)
    end
  end

  def parse_args
    Optimist.options do
      opt :queue_host, "Kafka messaging: hostname or IP", :type => :string, :default => ENV["QUEUE_HOST"] || "localhost"
      opt :queue_port, "Kafka messaging: port", :type => :integer, :default => (ENV["QUEUE_PORT"] || 9092).to_i
    end
  end

  def check_args(args)
    %i[queue_host queue_port].each do |arg|
      Optimist.die arg, "can't be blank" if args[arg].blank?
      Optimist.die arg, "can't be zero" if arg.to_s.index('port').present? && args[arg].zero?
    end
  end
end
