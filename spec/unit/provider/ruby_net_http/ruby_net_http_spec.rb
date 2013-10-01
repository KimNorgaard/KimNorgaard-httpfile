require 'spec_helper'

describe Puppet::Type.type(:httpfile).provider(:ruby_net_http) do
  include PuppetlabsSpec::Files

  before :each do
    @provider = described_class
    Puppet::Type.type(:httpfile).stubs(:defaultprovider).returns @type
    @valid_url = 'http://localhost:12345/ok_with_content_md5'
    @url_sidecar = 'http://localhost:12345//ok_with_sidecar'
    @url_404 = 'http://localhost:12345/404'
  end

  let :local_file do
    filename = tmpfilename('httpfile')
    unless File.exists? filename
      File.open(filename, 'w') do |f|
        f << 'test'
      end
    end
    filename
  end

  let :resource do
    Puppet::Type.type(:httpfile).new(
      :path   => local_file,
      :ensure => :present,
      :source => @valid_url,
    )
  end

  let :provider do
    provider = described_class.new
    provider.resource = resource
    provider
  end

  [:destroy, :create, :exists?].each do |method|
    it "should respond to #{method}" do
      provider.should respond_to method
    end
  end

  describe "with http connection" do
    it "should return a Net::HTTP connection" do
      provider.conn.class.should == Net::HTTP
      provider.conn.port.should == 12345
      provider.conn.address.should == 'localhost'
    end

    it "should fetch the HEAD with a URL returning 200" do
      expect {
        provider.http_head
      }.to_not raise_error
      provider.http_head.code.should == "200"
    end

    it "should not fetch the HEAD with a URL returning 404" do
      expect {
        provider.resource[:source] = @url_404
        provider.http_head
      }.to raise_error(Puppet::Error, /Failed to fetch file/)
      provider.http_head.code.should == "404"
    end

    it "should fetch the HEAD with a Content-MD5 heaer" do
      expect {
        provider.http_head
      }.to_not raise_error
      provider.http_head['Content-MD5'].is_a?(String).should == true
    end

    [:get, :post].each do |verb|
      it "should not with #{verb.upcase} fetch a URL returning 404" do
        provider.resource[:source] = @url_404
        req=provider.http_request(verb, provider.resource[:source])
        res=provider.conn.request(req)
        res.code.should == "404"
      end

      it "should #{verb.upcase} fetch a URL returning 200" do
        req=provider.http_request(verb, provider.resource[:source])
        res=provider.conn.request(req)
        res.code.should == "200"
      end

      it "should with #{verb.upcase} accept form_data, headers, body, content_type, user, pass" do
        provider.resource[:http_post_form_data] = { 'id' => 1 }
        provider.resource[:http_request_body] = 'test'
        provider.resource[:http_request_headers] = { 'X-Test' => 'test' }
        provider.resource[:http_request_content_type] = 'text/plain'
        provider.resource[:http_user] = 'foo'
        provider.resource[:http_pass] = 'bar'
        req=provider.http_request(verb, provider.resource[:source])
        res=provider.conn.request(req)
        res.code.should == "200"
      end

      it "should with #{verb.upcase} create HTTP Basic Auth header" do
        provider.resource[:http_user] = 'foo'
        provider.resource[:http_pass] = 'bar'
        req=provider.http_request(verb, provider.resource[:source])
        req['authorization'].should == 'Basic Zm9vOmJhcg=='
        res=provider.conn.request(req)
        res.code.should == "200"
      end

      it "should with #{verb.upcase} accept and merge options hash" do
        options = {
          :form_data => { 'id' => 1 },
          :headers => { 'X-Test' => 'test' },
          :http_user => 'foo',
          :http_pass => 'bar'
        }
        options[:body] = 'test' if verb == :get
        options[:content_type] = 'text/plain' if verb == :get
        req=provider.http_request(verb, provider.resource[:source], options)
        req.body.should == 'test' if verb == :get
        req.body.should == 'id=1' if verb == :post
        req['x-test'].should == 'test'
        req['content-type'].should == 'text/plain' if verb == :get
        req['content-type'].should == 'application/x-www-form-urlencoded' if verb == :post
        req['authorization'].should == 'Basic Zm9vOmJhcg=='
        res=provider.conn.request(req)
        res.code.should == "200"
      end
    end

    describe "with local_checksum" do
      it "should calculate an md5-sum for content_md5" do
        provider.resource[:checksum_type] = :content_md5
        provider.local_checksum.should == '098f6bcd4621d373cade4e832627b4f6'
      end

      it "should calculate an md5-sum for sidecar_md5" do
        provider.resource[:checksum_type] = :sidecar_md5
        provider.local_checksum.should == '098f6bcd4621d373cade4e832627b4f6'
      end

      it "should calculate an md5-sum for sidecar_sha1" do
        provider.resource[:checksum_type] = :sidecar_sha1
        provider.local_checksum.should == 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3'
      end
    end

    describe "with remote_checksum" do
      it "should calculate an md5-sum for content_md5" do
        provider.resource[:checksum_type] = :content_md5
        provider.remote_checksum.should == '098f6bcd4621d373cade4e832627b4f6'
      end

      it "should calculate an md5-sum for sidecar_md5" do
        provider.resource[:checksum_type] = :sidecar_md5
        provider.resource[:source] = @url_sidecar
        provider.remote_checksum.should == '098f6bcd4621d373cade4e832627b4f6'
      end

      it "should calculate an md5-sum for sidecar_sha1" do
        provider.resource[:checksum_type] = :sidecar_sha1
        provider.resource[:source] = @url_sidecar
        provider.remote_checksum.should == 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3'
      end
    end
  end
end
