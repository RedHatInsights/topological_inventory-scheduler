require "topological_inventory/scheduler/worker"

RSpec.describe TopologicalInventory::Scheduler::Worker do
  subject { described_class.new }

  describe "#run" do
    it "loads tasks and invokes refresh" do
      expect(subject).to receive(:load_running_tasks).and_return([])
      expect(subject).to receive(:service_instance_refresh)

      subject.run
    end
  end

  context "with initialized db" do
    before do
      @tenants = [
        create(:tenant, :name => 'Tenant 1'),
        create(:tenant, :name => 'Tenant 2')
      ]

      @sources = [
        create(:source, :tenant => @tenants[0]),
        create(:source, :tenant => @tenants[1])
      ]
      @service_instances = [
        create(:service_instance, :source_ref => '1', :source => @sources[0]),
        create(:service_instance, :source_ref => '2', :source => @sources[1]),
        create(:service_instance, :source_ref => '3', :source => @sources[0]),
        create(:service_instance, :source_ref => '4', :source => @sources[0])
      ]

      @service_offerings = [
        create(:service_offering, :source_ref => '1', :source => @sources[0])
      ]

      @tasks = [
        create(:task_svc_instance, :name => 'task1', :state => 'completed', :service_instance => @service_instances[0]),
        create(:task_svc_instance, :name => 'task2', :state => 'running', :service_instance => @service_instances[1]),
        create(:task_svc_instance, :name => 'task3', :state => 'running', :service_instance => @service_instances[2]),
        create(:task_svc_offering, :name => 'task4', :state => 'running', :service_offering => @service_offerings[0]),
        create(:task_svc_instance, :name => 'task5', :state => 'running', :service_instance => @service_instances[3])
      ]
    end

    describe "#load_running_tasks" do
      it "loads only running tasks and orders them by source_id" do
        tasks = subject.send(:load_running_tasks).to_a

        expect(Task.count).to eq(5)
        expect(tasks.size).to eq(3)
        expect(tasks.first).to eq(@tasks[2])
        expect(tasks.second).to eq(@tasks[4])
        expect(tasks.third).to eq(@tasks[1])
      end
    end

    describe "#service_instance_refresh" do
      before do
        Task.delete_all

        @tasks = [
          create(:task_svc_instance, :name => 'task1', :state => 'running', :service_instance => @service_instances[0]),
          create(:task_svc_instance, :name => 'task2', :state => 'running', :service_instance => @service_instances[1])
        ]
      end

      it "doesn't send tasks from unavailable Source" do
        tasks = subject.send(:load_running_tasks)
        expect(tasks.to_a.size).to eq(2)

        expect(subject).to(receive(:source_available?).with(@tasks[0])).and_return(true)
        expect(subject).to(receive(:source_available?).with(@tasks[1])).and_return(false)

        payload = {
          :source_id  => @sources[0].id.to_s,
          :source_uid => @sources[0].uid.to_s,
          :sent_at    => Time.now.utc.iso8601,
          :params     => [
            :request_context => @tasks[0].forwardable_headers,
            :source_ref      => @service_instances[0].source_ref,
            :task_id         => @tasks[0].id.to_s
          ]
        }

        expect(subject).to(receive(:send_payload).with(payload).and_return(nil))
        expect(subject).not_to(receive(:send_payload).with(hash_including(:source_id => @sources[1].id.to_s)))

        expect(subject).to(receive(:log_skipped_tasks).with({}))
        expect(subject).to(receive(:log_skipped_tasks).with(@tasks[1].source_id => [@tasks[1].id.to_s]))

        subject.send(:service_instance_refresh, tasks)
      end

      it "sends two payloads from 2 available Sources" do
        @tasks << create(:task_svc_instance, :name => 'task3', :state => 'running', :service_instance => @service_instances[2])


        tasks = subject.send(:load_running_tasks)
        expect(tasks.to_a.size).to eq(3)

        expect(subject).to receive(:source_available?).and_return(true).exactly(3).times

        payload = {
          :source_id  => @sources[0].id.to_s,
          :source_uid => @sources[0].uid.to_s,
          :sent_at    => Time.now.utc.iso8601,
          :params     => [{:request_context => @tasks[0].forwardable_headers,
                           :source_ref      => @service_instances[0].source_ref,
                           :task_id         => @tasks[0].id.to_s},
                          {:request_context => @tasks[2].forwardable_headers,
                           :source_ref      => @service_instances[2].source_ref,
                           :task_id         => @tasks[2].id.to_s}]
        }
        expect(subject).to(receive(:send_payload).with(payload).and_return(nil))

        payload = {
          :source_id  => @sources[1].id.to_s,
          :source_uid => @sources[1].uid.to_s,
          :sent_at    => Time.now.utc.iso8601,
          :params     => [{:request_context => @tasks[1].forwardable_headers,
                           :source_ref      => @service_instances[1].source_ref,
                           :task_id         => @tasks[1].id.to_s}]
        }
        expect(subject).to(receive(:send_payload).with(payload).and_return(nil))

        expect(subject).to(receive(:log_skipped_tasks).with({})).twice

        subject.send(:service_instance_refresh, tasks)
      end
    end
  end
end
