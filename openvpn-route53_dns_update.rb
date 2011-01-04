#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'syslog'
require 'route53'

# config
aws_access_key_id = 'AKIAIWMMPGNTMO44J7WA'
aws_secret_access_key = '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'
domain = 'vpn.careit.net.pl'

Syslog.open('openvpn-route53_dns_update', Syslog::LOG_PID | Syslog::LOG_NDELAY, Syslog::LOG_DAEMON)

begin
	operation = ARGV[0]
	ip = ARGV[1]
	cn = ARGV[2]

	fqdn = cn + '.' + domain + '.'

	if operation == 'delete'
		ip = '127.0.0.1'
	end
		
	conn = Route53::Connection.new(aws_access_key_id, aws_secret_access_key)

	zone = conn.get_zones(domain).first

	if zone.nil?
		Syslog.log(Syslog::LOG_INFO, "Unable to find the '#{zone}' zone.")
	end

	zone.get_records("A").each do |r|
		if r.name == fqdn
			r.delete
		end
	end

	record = Route53::DNSRecord.new(fqdn, "A", "60", [ip], zone)
	response = record.create

	if response.error?
		raise response.error
	else
		Syslog.log(Syslog::LOG_INFO, "Updated DNS record for cn='#{cn}' with ip='#{ip}'.")
	end
rescue Exception => e
	Syslog.log(Syslog::LOG_INFO, "Failed to update DNS for cn='#{cn}' with ip='#{ip}': '#{e.to_s}'")
end
