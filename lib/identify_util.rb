require 'socket'
require 'resolv'

module IdentifyUtil
  def ip_protocol_port(ip, protocol, port)
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

