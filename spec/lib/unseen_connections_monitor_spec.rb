describe UnseenConnectionsMonitor do
  # stub out calls to Airbrake
  before do
    allow(Airbrake).to receive(:notify)
    allow(Airbrake).to receive(:configure)
    allow(Airbrake).to receive(:close)
  end
  # create a temporary state file, delete it after tests
  let(:tempfile) { Tempfile.new.tap(&:close) }
  after { tempfile.unlink }

  let(:config) do
    {
      remember_for: 10,
      save_interval: 5,
      state_file: tempfile.path,
      networks: {
        production: /^10\..*/
      },
      airbrake: {
        project_id: 123,
        project_key: 'foo'
      }
    }
  end
  let(:monitor) { UnseenConnectionsMonitor.new(config: config) }

  describe '::new' do
    it { expect(monitor.config[:remember_for]).to eq(config[:remember_for]) }
    it { expect(monitor.config[:save_interval]).to eq(config[:save_interval]) }
    it { expect(monitor.config[:state_file]).to eq(config[:state_file]) }
    it { expect(monitor.config[:networks]).to eq(config[:networks]) }
    it { expect(monitor.config[:airbrake]).to eq(config[:airbrake]) }

    it 'configures an Airbrake notifier' do
      stub_config = double(Airbrake::Config)
      expect(Airbrake).to receive(:configure).and_yield(stub_config)
      expect(stub_config).to receive(:project_id=).with(config[:airbrake][:project_id])
      expect(stub_config).to receive(:project_key=).with(config[:airbrake][:project_key])
      expect(stub_config).to receive(:environment=).with(:production)
      monitor
    end

    context 'multiple networks' do
      it 'configures an Airbrake notifier for each network' do
        config[:networks] = {
          production: /^10\..*/,
          staging: /^192\.168\..*/
        }
        stub_config = double(Airbrake::Config)
        expect(Airbrake).to receive(:configure).twice.and_yield(stub_config)
        expect(stub_config).to receive(:project_id=).twice.with(config[:airbrake][:project_id])
        expect(stub_config).to receive(:project_key=).twice.with(config[:airbrake][:project_key])
        expect(stub_config).to receive(:environment=).once.with(:production)
        expect(stub_config).to receive(:environment=).once.with(:staging)
        monitor
      end
    end
  end

  describe '#config defaults' do
    let(:config) { {} }

    it { expect(monitor.config[:remember_for]).to eq(604800) }
    it { expect(monitor.config[:save_interval]).to eq(3600) }
    it { expect(monitor.config[:state_file]).to eq('unseen_connections.yml') }
    it { expect(monitor.config[:networks]).to eq(production: /.*/) }
    it { expect(monitor.networks).to eq([:production]) }
  end

  describe '#feed' do
    let(:arguments) do
      {
        datetime: Time.now.to_s,
        from_ip: '10.248.188.18',
        to_ip: '50.31.164.146',
        protocol: 'tcp',
        port: '443'
      }
    end
    let(:warning) do
      UnseenConnectionsMonitor::FirewallWarning.new(
        from: arguments[:from_ip],
        to: arguments[:to_ip],
        protocol: arguments[:protocol],
        port: arguments[:port]
      )
    end

    it 'notifies Airbrake about a new destination_ip:port connetions' do
      expect(Airbrake).to receive(:notify).with(warning, warning.params, :production)
      monitor.feed(**arguments)
    end

    it 'stores destination_ip:port connections in its state' do
      key = "#{arguments[:to_ip]}:#{arguments[:protocol]}/#{arguments[:port]}"
      timestamp = Time.parse(arguments[:datetime]).to_i
      monitor.feed(**arguments)
      expect(monitor.state.fetch(key)).to eq(timestamp)
    end

    it 'returns the warning instance' do
      warning = monitor.feed(**arguments)
      expect(warning).to be_kind_of(UnseenConnectionsMonitor::FirewallWarning)
      expect(warning.from).to eq(arguments[:from_ip])
      expect(warning.to).to eq(arguments[:to_ip])
      expect(warning.protocol).to eq(arguments[:protocol])
      expect(warning.port).to eq(arguments[:port])
    end

    it 'downcases the protocol' do
      arguments[:protocol] = 'ICMP'
      warning = monitor.feed(**arguments)
      expect(warning.protocol).to eq('icmp')
    end

    context 'multiple invocations' do
      it 'remembers destination_ip:port connections without notifying again' do
        monitor.feed(**arguments)
        expect(Airbrake).not_to receive(:notify)
        monitor.feed(**arguments)
      end

      it 'notifies again for connections that were dropped after :remember_for seconds within :save_interval' do
        monitor.feed(**arguments)
        connection_at = Time.parse(arguments[:datetime])
        Timecop.travel(connection_at + config[:remember_for] + 1) do
          # feed a connection, triggers cleaning of state
          monitor.feed(datetime: '2016-12-19T11:08:27.496Z', from_ip: '10.0.0.1', to_ip: '10.0.0.2', protocol: 'icmp', port: nil)
          # expect to be notified again for the particular connection
          expect(Airbrake).to receive(:notify).with(warning, warning.params, :production)
          monitor.feed(**arguments)
        end
      end

      it 'clears out remembered connections from state after :remember_for seconds within :save_interval' do
        connection_at = Time.parse(arguments[:datetime])
        old_key = "#{arguments[:from_ip]}:#{arguments[:protocol]}/#{arguments[:port]}"
        monitor.feed(**arguments)
        Timecop.travel(connection_at + config[:save_interval] + config[:remember_for]) do
          # feed a different connection, triggers cleaning of state
          monitor.feed(datetime: '2016-12-19T11:08:27.496Z', from_ip: '10.0.0.1', to_ip: '10.0.0.2', protocol: 'icmp', port: nil)
          expect(monitor.state).not_to have_key(old_key)
        end
      end

      it 'saves the state to disk as yaml after :save_interval seconds' do
        timestamp = Time.parse(arguments[:datetime]).to_i
        key = "#{arguments[:to_ip]}:#{arguments[:protocol]}/#{arguments[:port]}"

        Timecop.travel(Time.at(timestamp)) do
          monitor.feed(**arguments)
        end
        Timecop.travel(Time.at(monitor.last_save) + config[:save_interval] + 1) do
          monitor.feed(**arguments)

          state = YAML.load_file(config[:state_file])
          expect(state).to be_kind_of(Hash)
          expect(state.fetch(key)).to eq(timestamp)
        end
      end
    end
  end

  describe '#close' do
    it 'calls the Airbrake notifier to send out all remaining notifications' do
      expect(Airbrake).to receive(:close).with(:production)
      monitor.close
    end

    it 'saves its state' do
      expect(monitor).to receive(:save)
      monitor.close
    end

    context 'multiple networks' do
      it 'calls each Airbrake notifier to send out its remaining notifications' do
        config[:networks] = {
          production: /^10\..*/,
          staging: /^192\.168\..*/
        }
        expect(Airbrake).to receive(:close).once.with(:production)
        expect(Airbrake).to receive(:close).once.with(:staging)
        monitor.close
      end
    end
  end

end

