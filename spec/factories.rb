FactoryBot.define do
  factory :service_instance do
    initialize_with do
      ServiceInstance.where(:source_ref => source_ref)
                     .first_or_create(:name   => name,
                                      :source => source,
                                      :tenant => source.tenant)
    end

    name { "default" }
    source { association(:source) }
    source_ref { rand(1000).to_s }
  end

  factory :service_offering do
    initialize_with do
      ServiceOffering.where(:source_ref => source_ref)
                     .first_or_create(:description => description,
                                      :name        => name,
                                      :source      => source,
                                      :tenant      => source.tenant)
    end

    description { 'Test Service Offering' }
    name { "default" }
    source { association(:source) }
    source_ref { rand(1000).to_s }
  end

  factory :source do
    initialize_with do
      Source.where(:uid => uid)
            .first_or_create(:tenant => tenant)
    end

    tenant { association(:tenant) }
    uid    { SecureRandom.uuid }
  end

  factory :tenant do
    initialize_with do
      Tenant.where(:name => name)
            .first_or_create(:description     => description,
                             :external_tenant => external_tenant)
    end

    name            { "default" }
    description     { "Test tenant" }
    external_tenant { rand(1000).to_s }
  end
end
