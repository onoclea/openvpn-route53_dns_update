#!/usr/bin/env ruby

require 'net/http'
require 'route53'
require 'syslog'
require 'time'
require 'uri'

# config
aws_access_key_id = ''
aws_secret_access_key = ''
domain = ''

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

	if conn.nil?
		raise "Unable to connect to the Amazon Web Services."
	end

	zone = conn.get_zones(domain).first

	if zone.nil?
		raise "Unable to find the '#{zone}' zone."
	end

	zone.get_records("ANY").each do |r|
		if r.name == fqdn
			r.delete
		end
	end

	record = Route53::DNSRecord.new(fqdn, "A", "60", [ip], zone)
	response = record.create

	if response.error?
		raise response.error
	else
		Syslog.log(Syslog::LOG_INFO, "Updated A DNS record for cn='#{cn}' with ip='#{ip}'.")
	end

	# v (vendor) = onoclea
	# m (module) = aa ("at attention") ping-back-home software
	# mo (module object) = vpn
	record = Route53::DNSRecord.new(fqdn, "TXT", "60", ["\"v=onoclea m=aa mo=vpn cn:#{cn} ip:#{ip} ts:'#{Time.now.to_s}'\""], zone)
	response = record.create

	if response.error?
		raise response.error
	else
		Syslog.log(Syslog::LOG_INFO, "Updated TXT DNS record for cn='#{cn}' with ip='#{ip}'.")
	end
rescue Exception => e
	Syslog.log(Syslog::LOG_INFO, "Failed to update DNS for cn='#{cn}' with ip='#{ip}': '#{e.to_s}'")
end
