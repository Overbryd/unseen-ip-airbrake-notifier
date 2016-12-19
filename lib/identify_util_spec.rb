describe IdentifyUtil do
  describe '::ip_protocol_port' do
    before do
      expect(Resolv).to receive(:getname).with('127.0.0.1').and_return('localhost')
      expect(Socket).to receive(:getservbyport).with(53, 'tcp').and_return('domain')
    end
    subject { IdentifyUtil.ip_protocol_port('127.0.0.1', 'tcp', '53') }
    it { expect(subject).to eq(ip: '127.0.0.1', protocol: 'tcp', port: '53', service_name: 'domain', host: 'localhost') }
  end
end

