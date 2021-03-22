require 'manageiq-messaging'
require 'topological_inventory/scheduler/logging'
require 'topological_inventory/scheduler/sources_api_client'
require 'topological_inventory/scheduler/clowder_config'

module TopologicalInventory
  module Scheduler
    class Worker
      include Logging

      REFRESH_QUEUE_NAME = 'platform.topological-inventory.collector-ansible-tower'.freeze

      def initialize(opts = {})
        messaging_client_opts = opts.select { |k, _| %i[host port].include?(k) }
        self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
      end

      def run
        logger.info('Topological Inventory Refresh Scheduler started...')

        tasks = load_running_tasks
        service_instance_refresh(tasks)

        logger.info('Topological Inventory Refresh Scheduler finished...')
      end

      private

      attr_accessor :messaging_client_opts

      def service_instance_refresh(tasks)
        logger.info('ServiceInstance#refresh - Started')
        payload, skipped = {}, {}

        with_tasks(tasks) do |task|
          # grouping requests by Source
          # - tasks are ordered by source_id
          if payload[:source_id].present? && payload[:source_id] != task.source_id.to_s
            send_payload(payload)
            log_skipped_tasks(skipped)
            payload, skipped = {}, {}
          end

          unless source_available?(task)
            skipped[task.source_id] ||= []
            skipped[task.source_id] << task.id.to_s
            next
          end

          log_with(task.forwardable_headers['x-rh-insights-request-id']) do
            logger.debug("ServiceInstance#refresh - Task(id: #{task.id}), ServiceInstance(source_ref: #{task.target_source_ref}), Source(id: #{task.source_id}")

            payload[:source_id]  = task.source_id.to_s
            payload[:source_uid] = task.source_uid.to_s
            payload[:sent_at]    = Time.now.utc.iso8601

            payload[:params] ||= []
            payload[:params] << {
              :request_context => task.forwardable_headers,
              :source_ref      => task.target_source_ref,
              :task_id         => task.id.to_s
            }
          end
        end

        # sending remaining data
        send_payload(payload) if payload[:params].present?
        log_skipped_tasks(skipped)
      rescue => e
        logger.error("ServiceInstance#refresh - Failed. Task(id: #{tasks_id(tasks).join(' | ')}). Error: #{e.message}, #{e.backtrace.join('\n')}")
      end

      # TODO: restrict targeted refreshes to AnsibleTower Source
      # Not needed now as we don't have service_instance tasks not belonging to Tower
      def load_running_tasks
        Task.where(:state => 'running', :target_type => 'ServiceInstance')
            .joins(:source)
            .select('tasks.id, tasks.source_id, tasks.target_source_ref, tasks.forwardable_headers, sources.uid as source_uid')
            .order('source_id')
      end

      # find_each is ignoring ordering, has to be self-implemented
      # https://api.rubyonrails.org/classes/ActiveRecord/Batches.html
      def with_tasks(tasks)
        limit, offset = 100, 0
        loop do
          tasks_cnt = 0
          tasks.limit(limit).offset(offset).each do |task|
            tasks_cnt += 1
            yield task
          end

          if tasks_cnt == limit
            offset += limit
          else
            break
          end
        end
      end

      def tasks_id(tasks = load_running_tasks)
        tasks.pluck(:id)
      end

      # TODO: Update task.status = 'error' without request_context immediately?
      def source_available?(task)
        return false if task.forwardable_headers.nil?

        api_client.source_available?(task.source_id, task.forwardable_headers)
      rescue => e
        logger.error("ServiceInstance#refresh - Task(id: #{task.id}), Error: #{e.message}, #{e.backtrace.join('\n')}")
        false
      end

      def send_payload(payload)
        logger.info("ServiceInstance#refresh - publishing to kafka: Source(id: #{payload[:source_id]})...")
        messaging_client.publish_topic(
          :service => TopologicalInventory::Scheduler::ClowderConfig.kafka_topic(REFRESH_QUEUE_NAME),
          :event   => 'ServiceInstance.refresh',
          :payload => payload.to_json
        )
        logger.info("ServiceInstance#refresh - publishing to kafka: Source(id: #{payload[:source_id]})...Complete")
      end

      def log_skipped_tasks(skipped)
        skipped.each_pair do |source_id, tasks_id|
          logger.warn("ServiceInstance#refresh - Skipped Tasks (id: #{tasks_id.join(' | ')}). Source is unavailable (id: #{source_id})")
        end
      end

      def messaging_client
        @messaging_client ||= ManageIQ::Messaging::Client.open(messaging_client_opts)
      end

      def api_client
        @api_client ||= TopologicalInventory::Scheduler::SourcesApiClient.new
      end

      def default_messaging_opts
        {
          :encoding => 'json',
          :protocol => :Kafka
        }
      end
    end
  end
end
