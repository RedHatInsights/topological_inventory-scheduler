require "topological_inventory/scheduler/database_tools"

RSpec.describe TopologicalInventory::Scheduler::DatabaseTools do
  subject { described_class.new }

  describe "#remove_old_records" do
    let(:uuids) { ['f41743e5-639b-411f-89a7-ed1a4cb9d860', 'c2cb467d-156f-41bb-bdab-a7d311b54f1b'] }
    let(:tenant)   { Tenant.create(:name => 'testing_tenant', :external_tenant => 'testing') }
    let(:source)   { Source.create(:uid => '31b5338b-685d-4056-ba39-d00b4d7f19cc', :tenant_id => tenant.id) }
    let(:threshold) { TopologicalInventory::Scheduler::DatabaseTools::REFRESH_STATES_TIME_THRESHOLD }

    before(:all) do
      Tenant.delete_all
      Source.delete_all
    end

    after(:each) do
      Tenant.delete_all
      Source.delete_all
    end

    it 'removes old records' do
      rs  = create_refresh_state(source.id, uuids[0])
      rs.updated_at = Time.now.utc - threshold
      rs.save
      create_refresh_state_part(rs.id, uuids[0])
      create_refresh_state_part(rs.id, uuids[1])

      expect(RefreshState.count).to eq(1)
      expect(RefreshStatePart.count).to eq(2)

      subject.remove_old_records

      expect(RefreshState.count).to eq(0)
      expect(RefreshStatePart.count).to eq(0)
    end

    it 'does not remove younger records' do
      rs  = create_refresh_state(source.id, uuids[0])
      create_refresh_state_part(rs.id, uuids[0])

      expect(RefreshState.count).to eq(1)
      expect(RefreshStatePart.count).to eq(1)

      subject.remove_old_records

      expect(RefreshState.count).to eq(1)
      expect(RefreshStatePart.count).to eq(1)
    end

    it 'does not remove related objects' do
      rs  = create_refresh_state(source.id, uuids[0])
      rs.updated_at = Time.now.utc - threshold
      rs.save
      rsp = create_refresh_state_part(rs.id, uuids[0])
      Vm.create(
        :tenant_id             => tenant.id,
        :source_id             => source.id,
        :source_ref            => 'source_ref_test',
        :refresh_state_part_id => rsp.id
      )
      Host.create(
        :tenant_id             => tenant.id,
        :source_id             => source.id,
        :source_ref            => 'source_ref_test',
        :refresh_state_part_id => rsp.id
      )

      expect(Vm.count).to eq(1)
      expect(Host.count).to eq(1)
      expect(RefreshState.count).to eq(1)
      expect(RefreshStatePart.count).to eq(1)

      subject.remove_old_records

      expect(Vm.count).to eq(1)
      expect(Vm.first.refresh_state_part_id).to be_nil
      expect(Host.count).to eq(1)
      expect(Host.first.refresh_state_part_id).to be_nil
      expect(RefreshState.count).to eq(0)
      expect(RefreshStatePart.count).to eq(0)
    end

    def create_refresh_state(source_id, uuid)
      RefreshState.create(
        :source_id         => source_id,
        :tenant_id         => tenant.id,
        :uuid              => uuid,
        :sweep_scope       => ['vms', 'hosts']
      )
    end

    def create_refresh_state_part(refresh_state_id, uuid)
      RefreshStatePart.create(
        :refresh_state_id => refresh_state_id,
        :tenant_id        => tenant.id,
        :uuid             => uuid
      )
    end
  end
end
