#!/usr/bin/env ruby
# unseen_connections.rb: script to notify unseen tcp connection attempts
#
# Usage:
#
#   elktail -f '%@timestamp,%src_ip,%dst_ip,%protocol,%src_port' 'type:cisco-firewall AND action:Built AND direction:outbound' \
#   | ruby unseen_connections.rb
#
# Synopsis:
#
#   The script expects input on STDIN, one line per firewall log entry.
#   Each line must be formatted, including the fields %@timestamp, %src_ip, %dst_ip, %protocol and %src_port.
#
#     %@timestamp,%src_ip,%dst_ip,%protocol,%src_port\n
#
#   e.g.
#
#     2016-11-29T10:36:05.990Z,50.31.164.146,10.248.177.12,TCP,443\n
#
#   It remembers each destination ip:port combination for a given time.
#   Over multiple runs it restores and saves its state with a YAML file.
#
#   New ip:port combinations are reported to Airbrake with
#   their respective environment and additional information.
#
#   Airbrake in turn alerts the current Sherrif in charge via Pivotaltracker.
#
# Dependencies:
#
#   * A tool that can stream data out of the ELK stack and format its output as described above.
#     For example 'elktail' (https://github.com/knes1/elktail/releases) does the job really well.
#
#   * An Airbrake account project_id and project_key.

begin
  require 'bundler'
  Bundler.setup
rescue
  require 'rubygems'
end
require 'airbrake-ruby'
require 'yaml'
require 'time'
require_relative './identify_ip_protocol_port.rb'

class FirewallWarning < StandardError; end

CONFIG = YAML.load_file('config.yml')
NETWORKS = CONFIG.fetch(:networks)
REMEMBER_FOR = CONFIG.fetch(:remember_for)
SAVE_INTERVAL = CONFIG.fetch(:save_interval)

NETWORKS.each do |name, _|
  Airbrake.configure(name) do |c|
    c.project_id = CONFIG.fetch(:airbrake).fetch(:project_id)
    c.project_key = CONFIG.fetch(:airbrake).fetch(:project_key)
    c.environment = name
  end
end

def notify(from:,to:,protocol:,port:)
  name, _ = NETWORKS.find { |_, regexp| from =~ regexp }
  message = "unseen #{protocol} connection from #{from} to #{to}:#{port}"
  params = IdentifyUtil.identify_ip_protocol_port(to, protocol, port).merge(from: from)
  Airbrake.notify(FirewallWarning.new(message), params, name || :production)
  STDERR.puts(message)
end

def save(state)
  File.open("unseen_connections.yml", "w") { |f| f.write(state.to_yaml) }
end

last_save = Time.now.to_i
state = YAML.load_file("unseen_connections.yml") rescue {}

at_exit do
  NETWORKS.each { |name, _| Airbrake.close(name) }
  save(state)
end

while line = STDIN.gets
  now = Time.now.to_i
  datetime, src_ip, dst_ip, protocol, port = line.strip.split(",")
  timestamp = Time.parse(datetime).to_i
  protocol = protocol.downcase
  key = "#{src_ip}:#{port}"

  notify(from: dst_ip, to: src_ip, protocol: protocol, port: port) unless state.has_key?(key)
  state[key] = timestamp
  if last_save < now - SAVE_INTERVAL
    state.reject! { |_, last_attempt| last_attempt < now - REMEMBER_FOR }
    save(state)
    last_save = now
  end
end

