module Bosh::Director
  class LocalDnsEncoderManager
    def self.persist_az_names(azs)
      azs.each do |azname|
        self.encode_az(azname)
      end
    end

    def self.create_dns_encoder(use_short_dns_names=false)
      az_hash = {}

      Models::LocalDnsEncodedAz.all.each do |item|
        az_hash[item.name] = item.id.to_s
      end

      service_groups = {}
      Bosh::Director::Models::LocalDnsServiceGroup.all_groups_eager_load.each do |item|
        service_groups[{
          instance_group: item.instance_group.name,
          deployment: item.instance_group.deployment.name,
          network: item.network.name
        }] = item.id.to_s
      end

      Bosh::Director::DnsEncoder.new(service_groups, az_hash, use_short_dns_names)
    end

    def self.new_encoder_with_updated_index(plan)
      persist_az_names(plan.availability_zones.map(&:name))
      persist_service_groups(plan)
      create_dns_encoder#(plan.short_dns_names)
    end

    private

    def self.encode_az(name)
      Models::LocalDnsEncodedAz.find_or_create(name: name)
    end

    def self.encode_instance_group(name, deployment_model)
      Models::LocalDnsEncodedInstanceGroup.find_or_create(
        name: name,
        deployment: deployment_model)
    end

    def self.encode_network(name)
      Models::LocalDnsEncodedNetwork.find_or_create(name: name)
    end

    def self.encode_service_group(instance_group, network)
      Models::LocalDnsServiceGroup.find_or_create(
        instance_group: instance_group,
        network: network)
    end

    def self.persist_service_groups(plan)
      deployment_model = plan.model

      plan.instance_groups.each do |ig|
        ig_encoded = encode_instance_group(ig.name, deployment_model)
        ig.networks.each do |net|
          net_encoded = encode_network(net.name)
          encode_service_group(ig_encoded, net_encoded)
        end
      end
    end
  end
end
