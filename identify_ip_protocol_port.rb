#!/usr/bin/env ruby
# identify_ip_port.rb: script to identify an ip port combination
#
# Usage:
#
#   $ ruby identify_ip_port.rb 8.8.8.8 udp 53
#   {
#     "ip": "8.8.8.8",
#     "protocol": "udp",
#     "port": "53",
#     "service_name": "domain",
#     "host": "google-public-dns-a.google.com"
#   }
#
require 'socket'
require 'resolv'
require 'json'

module IdentifyUtil
  def identify_ip_protocol_port(ip, protocol, port)
    {
      ip: ip,
      protocol: protocol,
      port: port,
      service_name: (
        Socket.getservbyport(port.to_i, protocol) rescue nil
      ),
      host: (
        Resolv.getname(ip) rescue nil
      )
    }
  end

  extend self
end

if __FILE__ == $0
  ip, protocol, port = *ARGV
  puts JSON.pretty_generate(IdentifyUtil.identify_ip_protocol_port(ip, protocol, port))
end

