require 'spec_helper'
require 'puppet/file_bucket/dipper'

describe Puppet::Type.type(:httpfile).provider(:ruby_net_http), '(integration)' do
  include PuppetlabsSpec::Files

  before :each do
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup) 
    Puppet::Type.type(:httpfile).stubs(:defaultprovider).returns described_class
  end

  let(:valid_url) {'http://localhost:12345/test_ok'}

  let :non_existing_file do
    filename = tmpfilename('non_existing_file')
  end

  let :local_file do
    filename = tmpfilename('httpfile')
    File.open(filename, 'w') do |f|
      f << 'test'
    end
    filename
  end

  let :resource_absent do
    Puppet::Type.type(:httpfile).new(
      :ensure => :absent,
      :path   => non_existing_file,
      :source => valid_url,
    )
  end

  let :resource_present do
    Puppet::Type.type(:httpfile).new(
      :ensure => :present,
      :path   => local_file,
      :source => valid_url,
    )
  end

  def is_file?(file)
    File.exists?(file)
  end

  def run_in_catalog(*resources)
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    resources.each do |resource|
      resource.expects(:err).never
      catalog.add_resource(resource)
    end
    catalog.apply
  end

  describe "while managing a httpfile resource" do
    context "when ensure is :absent" do
      it "should not do anything if file is absent" do
        run_in_catalog(resource_absent)
        expect(is_file?(resource_absent[:path])).to be_false
      end

      it "should remove existing file if present" do
        File.open(resource_absent[:path], 'w') {}
        expect(is_file?(resource_absent[:path])).to be_true
        run_in_catalog(resource_absent)
        expect(is_file?(resource_absent[:path])).to be_false
      end
    end

    context "when ensure is :present" do
      [:content_md5, :sidecar_md5, :sidecar_sha1].each do |checksum_type|
        context "when checksum_type is :#{checksum_type}" do
          context "when there is no local file" do
            it "should download the file" do
              resource_present[:checksum_type] = checksum_type
              resource_present[:path] = tmpfilename('file_does_not_exist')
              expect(is_file?(resource_present[:path])).to be_false
              run_in_catalog(resource_present)
              expect(is_file?(resource_present[:path])).to be_true
            end
          end

          context "when the checksums differ" do
            pending "should update the file"
          end

          context "when the checksums match" do
            pending "should not update the file"
          end

          context "when using http basic auth" do
            pending "should work with valid credentials"
            pending "should fail with wrong credentials"
          end
        end
      end

      pending "should work with http options"
      pending "should update a file using sidecar_source for checksum"
      pending "should work using different verbs"
      pending "should work with increased timeout"
      pending "should work using different sidecar verbs"
      pending "should work with sidecar http options"

      pending "should not download if the expected checksum does not match"
      pending "should fail if the downloaded file's checksum does not match the expected checksum"

      # maybe implement "double_check_checksum: true|false"
      pending "should fail if the downloaded file's checksum does not match the promised checksum"

      pending "should download with :force despite :expected_checksum"
      pending "should download with :force despite anything? TODO: how?"

      pending "https should work without verity cert"
      pending "https should work with ca_path"
      pending "https should work with ca_file"
      pending "https should work with sidecar_source"
    end
  end
end
