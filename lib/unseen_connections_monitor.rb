require 'airbrake-ruby'
require 'yaml'
require 'time'
require 'tempfile'
require 'fileutils'
require_relative './identify_util.rb'

class UnseenConnectionsMonitor

  class FirewallWarning < StandardError
    attr_reader :from, :to, :protocol, :port

    def initialize(from:, to:, protocol:, port:)
      super("unseen #{protocol} connection from #{from} to #{to}:#{port}")
      @from, @to, @protocol, @port = from, to, protocol, port
    end

    def params
      IdentifyUtil.ip_protocol_port(to, protocol, port).merge(from: from)
    end

    def ==(other)
      message == other.message
    end
    alias_method :eq?, :==
  end

  DEFAULTS = {
    remember_for: 604800,
    save_interval: 3600,
    state_file: "unseen_connections.yml",
    networks: {
      production: /.*/
    }
  }

  attr_reader :config

  def initialize(config:)
    @config = config
    @config.default_proc = proc { |h,k| h[k] = DEFAULTS[k] }
    DEFAULTS.keys.each { |k| @config[k] }
    configure_airbrake
  end

  def close
    networks.each { |name| Airbrake.close(name) }
    save
  end

  # taken from activesupport File::atomic_write
  def save
    state_file = config.fetch(:state_file)
    tempfile = Tempfile.new(File.basename(state_file), Dir.tmpdir)
    tempfile.write(state.to_yaml)
    tempfile.close
    begin
      # Get original file permissions
      old_stat = File.stat(state_file)
    rescue Errno::ENOENT
      # No old permissions, write a temp file to determine the defaults
      check_name = File.join(File.dirname(file_name), ".permissions_check.#{Thread.current.object_id}.#{Process.pid}.#{rand(1000000)}")
      File.open(check_name, "w") { }
      old_stat = File.stat(check_name)
      File.unlink(check_name)
    end
    FileUtils.mv(tempfile.path, state_file)
    File.chown(old_stat.uid, old_stat.gid, state_file)
    File.chmod(old_stat.mode, state_file)
    @last_save = Time.now.to_i
  end

  def state
    @state ||= begin
      @last_save = Time.now.to_i
      YAML.load_file(config.fetch(:state_file)) || {} rescue {}
    end
  end

  def last_save
    @last_save || 0
  end

  def feed(datetime:,from_ip:,protocol:,to_ip:,port:)
    timestamp = Time.parse(datetime).to_i
    protocol = protocol.downcase
    key = "#{to_ip}:#{protocol}/#{port}"

    warning = notify(from: from_ip, to: to_ip, protocol: protocol, port: port) unless state.has_key?(key)
    state[key] = timestamp
    warning
  ensure
    housekeeping
  end

  def networks
    config.fetch(:networks).keys
  end

  private

  def notify(from:,to:,protocol:,port:)
    warning = FirewallWarning.new(from: from, to: to, protocol: protocol, port: port)
    Airbrake.notify(warning, warning.params, network_name(from) || :production)
    warning
  end

  def network_name(from)
    name, _ = config.fetch(:networks).find { |_, regexp| from =~ regexp }
    name
  end

  def housekeeping
    now = Time.now.to_i
    state.reject! { |_, last_attempt| last_attempt < now - config.fetch(:remember_for)  }
    save if last_save < now - config.fetch(:save_interval)
  end

  def configure_airbrake
    networks.each do |name, _|
      Airbrake.configure(name) do |c|
        c.project_id = config.fetch(:airbrake).fetch(:project_id)
        c.project_key = config.fetch(:airbrake).fetch(:project_key)
        c.environment = name
      end
    end
  end

end

