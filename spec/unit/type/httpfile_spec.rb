require 'spec_helper'
require 'webrick'
require 'digest/md5'

describe Puppet::Type.type(:httpfile) do
  before :each do
    @type = described_class
    @valid_name = '/tmp/test.txt'
    @valid_url = 'http://localhost:12345/ok_with_content_md5'
  end

  it "should exist" do
    @type.should_not be_nil
  end

  it "should have :path as its keyattribute" do
    @type.key_attributes.should == [:path]
  end

  describe "when validating attribuets" do
    [:path, :source, :force, :print_progress, :checksum_type,
     :sidecar_source, :expected_checksum, :http_verb, :http_ssl_verify,
     :http_ssl_ca_file, :http_ssl_ca_path, :http_request_content_type,
     :http_request_headers, :http_request_body, :http_post_form_data,
     :http_open_timeout, :http_user, :http_pass, :sidecar_http_verb,
     :sidecar_http_post_form_data, :sidecar_http_request_body,
     :sidecar_http_request_headers, :sidecar_http_request_content_type,
     :sidecar_http_user, :sidecar_http_pass].each do |param|
      it "should have a #{param} parameter" do
        @type.attrtype(param).should == :param
      end
    end
  end

  describe "when validating value" do
    describe "for ensure" do
      it "should support present" do
        expect {
          @type.new(
            :path   => @valid_name,
            :source => @valid_url,
            :ensure => :present
          )
        }.to_not raise_error
      end

      it "should support absent" do
        expect {
          @type.new(
            :path   => @valid_name,
            :source => @valid_url,
            :ensure => :absent
          )
        }.to_not raise_error
      end

      it "should not support other values" do
        expect {
          @type.new(
            :path   => @valid_name,
            :source => @valid_url,
            :ensure => :notvalid
          )
        }.to raise_error(Puppet::Error, /Invalid value/)
      end
    end

    describe "for path/name" do
      it "should not be missing" do
        expect {
          @type.new(
            :source => @valid_url,
            :ensure => :present
          )
        }.to raise_error(Puppet::Error, /Title or name must be provided/)
      end

      it "should support a valid path/name" do
        expect {
          @type.new(
            :path   => @valid_name,
            :source => @valid_url,
            :ensure => :present
          )
        }.to_not raise_error
      end

      it "should not support a relative path/name" do
        expect {
          @type.new(
            :path   => '../test.txt',
            :source => @valid_url,
            :ensure => :present
          )
        }.to raise_error(Puppet::Error, /is not fully qualified/)

        expect {
          @type.new(
            :path   => 'test/test.txt',
            :source => @valid_url,
            :ensure => :present
          )
        }.to raise_error(Puppet::Error, /is not fully qualified/)
      end

      it "should not support an empty path/name" do
        expect {
          @type.new(
            :path   => '',
            :source => @valid_url,
            :ensure => :present
          )
        }.to raise_error(Puppet::Error, /path must be set to something/)
      end
    end

    describe "for source" do
      it "should not be missing" do
        expect {
          @type.new(
            :path   => @valid_name,
            :ensure => :present
          )
        }.to raise_error(Puppet::Error, /source is required/)
      end

      it "should support http and https" do
        expect {
          @type.new(
            :source => 'http://example.com/',
            :path   => @valid_name,
            :ensure => :present
          )
        }.to_not raise_error

        expect {
          @type.new(
            :source => 'https://example.com/',
            :path   => @valid_name,
            :ensure => :present
          )
        }.to_not raise_error
      end

      it "should not support other protocols" do
        expect {
          @type.new(
            :source => 'ftp://example.com/',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use URLs of type/)

        expect {
          @type.new(
            :source => 'gopher://example.com/',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use URLs of type/)
      end

      it "should not support invalid urls" do
        expect {
          @type.new(
            :source => '"http://website.com/dirs/filex[a]',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Invalid URL/)

        expect {
          @type.new(
            :source => '>>://test',
            :path   => @valid_name,
            :ensure => :present
          ) 
       
        }.to raise_error(Puppet::Error, /Invalid URL/)

        expect {
          @type.new(
            :source => 'http://?]',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Invalid URL/)

        expect {
          @type.new(
            :source => 'http://]',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Invalid URL/)
      end

      it "should not support relative urls" do
        expect {
          @type.new(
            :source => '../test.html',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use relative URLs/)

        expect {
          @type.new(
            :source => 'test/test.html',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use relative URLs/)
      end

      it "should not support opaque urls" do
        expect {
          @type.new(
            :source => 'mailto:mail@example.com',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use opaque URLs/)

        expect {
          @type.new(
            :source => 'data:;base64,dGVzdAo=',
            :path   => @valid_name,
            :ensure => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use opaque URLs/)
      end
    end

    describe "for sidecar_source" do
      it "should support http and https" do
        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'http://example.com/', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to_not raise_error
        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'https://example.com/', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to_not raise_error
      end

      it "should not support other protocols" do
        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'ftp://example.com/', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use URLs of type/)

        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'gopher://example.com/', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use URLs of type/)
      end

      it "should not support invalid urls" do
        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => '"http://website.com/dirs/filex[a]', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Invalid URL/)

        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => '>>://test', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Invalid URL/)

        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'http://?]', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Invalid URL/)

        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'http://]', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Invalid URL/)
      end

      it "should not support relative urls" do
        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => '../test.html', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use relative URLs/)

        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'test/test.html', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use relative URLs/)
      end

      it "should not support opaque urls" do
        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'mailto:mail@example.com', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use opaque URLs/)

        expect { 
          @type.new(
            :source         => @valid_url, 
            :sidecar_source => 'data:;base64,dGVzdAo=', 
            :path           => @valid_name, 
            :ensure         => :present
          ) 
        }.to raise_error(Puppet::Error, /Cannot use opaque URLs/)
      end
    end

    # Booleans
    [:force, :print_progress, :http_ssl_verify].each do |bool|
      describe "for #{bool}" do
        it "should support true" do
          expect {
            @type.new(
              :source => @valid_url, 
              :path   => @valid_name, 
              :ensure => :present, 
              bool    => :true
            ) 
          }.to_not raise_error
        end

        it "should support false" do
          expect { 
            @type.new(
              :source => @valid_url, 
              :path   => @valid_name, 
              :ensure => :present, 
              bool    => :false
            ) 
          }.to_not raise_error
        end

        it "should not support other values" do
          expect { 
            @type.new(
              :source => @valid_url, 
              :path   => @valid_name, 
              :ensure => :present, 
              bool    => 'string'
            ) 
          }.to raise_error

          expect { 
            @type.new(
              :source => @valid_url, 
              :path   => @valid_name, 
              :ensure => :present, 
              bool    => 0
            ) 
          }.to raise_error
        end
      end
    end

    describe "for checksum_type" do
      [:content_md5, :sidecar_md5, :sidecar_sha1].each do |type|
        it "should support #{type}" do
          expect { 
            @type.new(
              :source        => @valid_url, 
              :path          => @valid_name, 
              :ensure        => :present, 
              :checksum_type => type
            ) 
          }.to_not raise_error
        end
      end

      it "should not support other types" do
        expect {
          @type.new(
            :source         => @valid_url,
            :path           => @valid_name,
            :ensure         => :present,
            :checksum_type  => :not_a_valid_type
          )
        }.to raise_error(Puppet::Error, /Invalid value/)
      end

      it "should default to :content_md5" do
        @type.new(
          :source => @valid_url,
          :path   => @valid_name,
          :ensure => :present
        )[:checksum_type].should == :content_md5
      end
    end

    describe "for expected_checksum" do
      it "should support valid md5 checksum with checksum_type = content_md5" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :content_md5,
            :expected_checksum => 'd8e8fca2dc0f896fd7cb4cb0031ba249'
          )
        }.to_not raise_error

      end

      it "should support valid md5 checksum with checksum_type = sidecar_md5" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_md5,
            :expected_checksum => 'd8e8fca2dc0f896fd7cb4cb0031ba249'
          )
        }.to_not raise_error
      end

      it "should support valid sha1 checksum with checksum_type = sidecar_sha1" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_sha1,
            :expected_checksum => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
          )
        }.to_not raise_error
      end

      it "should not support invalid md5 checksum with checksum_type = content_md5" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :content_md5,
            :expected_checksum => 'shortsum'
          )
        }.to raise_error(Puppet::Error, /Not a MD5 hex digest/)

        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :content_md5,
            :expected_checksum => 'longsumlongsumlongsumlongsumlongsumlongsumlongsum'
          )
        }.to raise_error(Puppet::Error, /Not a MD5 hex digest/)
      end

      it "should not support invalid md5 checksum with checksum_type = sidecar_md5" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_md5,
            :expected_checksum => 'shortsum'
          )
        }.to raise_error(Puppet::Error, /Not a MD5 hex digest/)

        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_md5,
            :expected_checksum => 'longsumlongsumlongsumlongsumlongsumlongsumlongsum'
          )
        }.to raise_error(Puppet::Error, /Not a MD5 hex digest/)
      end

      it "should not support invalid sha1 checksum with checksum_type = sidecar_sha1" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_sha1,
            :expected_checksum => 'shortsum'
          )
        }.to raise_error(Puppet::Error, /Not a SHA1 hex digest/)

        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_sha1,
            :expected_checksum => 'longsumlongsumlongsumlongsumlongsumlongsumlongsum'
          )
        }.to raise_error(Puppet::Error, /Not a SHA1 hex digest/)
      end

      it "should not support valid md5 checksum with checksum_type = sidecar_sha1" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_sha1,
            :expected_checksum => 'd8e8fca2dc0f896fd7cb4cb0031ba249'
          )
        }.to raise_error(Puppet::Error, /Not a SHA1 hex digest/)
      end

      it "should not support valid sha1 checksum with checksum_type = sidecar_md5" do
        expect {
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :checksum_type     => :sidecar_md5,
            :expected_checksum => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
          )
        }.to raise_error(Puppet::Error, /Not a MD5 hex digest/)
      end
    end

    describe "for http_verb" do
      [:get, :post].each do |type|
        it "should support #{type}" do
          expect { 
            @type.new(
              :source    => @valid_url, 
              :path      => @valid_name, 
              :ensure    => :present, 
              :http_verb => type
            ) 
          }.to_not raise_error
        end
      end

      it "should not support other types" do
        expect {
          @type.new(
            :source     => @valid_url,
            :path       => @valid_name,
            :ensure     => :present,
            :http_verb  => :head
          )
        }.to raise_error(Puppet::Error, /Invalid value/)
      end

      it "should default to :get" do
        @type.new(
          :source => @valid_url,
          :path   => @valid_name,
          :ensure => :present
        )[:http_verb].should == :get
      end
    end

    describe "for sidecar_http_verb" do
      [:get, :post].each do |type|
        it "should support #{type}" do
          expect { 
            @type.new(
              :source            => @valid_url, 
              :path              => @valid_name, 
              :ensure            => :present, 
              :sidecar_http_verb => type
            ) 
          }.to_not raise_error
        end
      end

      it "should not support other types" do
        expect {
          @type.new(
            :source             => @valid_url,
            :path               => @valid_name,
            :ensure             => :present,
            :sidecar_http_verb  => :head
          )
        }.to raise_error(Puppet::Error, /Invalid value/)
      end
    end

    [:http_request_headers, :sidecar_http_request_headers].each do |param|
      describe "for #{param}" do
        it "should accept accept a hash" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => {'X-Test' => 'true'},
            )
          }.to_not raise_error
        end

        it "should not accept strings" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => 'string',
            )
          }.to raise_error(Puppet::Error)
        end

        it "should not accept integers" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => 42,
            )
          }.to raise_error(Puppet::Error)
        end

        it "should not accept arrays" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => [1, 2, 3],
            )
          }.to raise_error(Puppet::Error)
        end
      end
    end

    [:http_post_form_data, :sidecar_http_post_form_data].each do |param|
      describe "for #{param}" do
        it "should accept accept a hash" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => {'X-Test' => 'true'},
            )
          }.to_not raise_error
        end

        it "should not accept strings" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => 'string',
            )
          }.to raise_error(Puppet::Error)
        end

        it "should not accept integers" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => 42,
            )
          }.to raise_error(Puppet::Error)
        end

        it "should not accept arrays" do
          expect{
            @type.new(
              :source => @valid_url,
              :path   => @valid_name,
              :ensure => :present,
              param   => [1, 2, 3],
            )
          }.to raise_error(Puppet::Error)
        end
      end
    end

    describe "for http_open_timeout" do
      it "should accept an integer" do
        expect{
          @type.new(
            :source            => @valid_url,
            :path              => @valid_name,
            :ensure            => :present,
            :http_open_timeout => 1,
          )
        }.to_not raise_error
      end

      it "should not accept arrays" do
          expect{
            @type.new(
              :source            => @valid_url,
              :path              => @valid_name,
              :ensure            => :present,
              :http_open_timeout => [1, 2, 3],
            )
          }.to raise_error(Puppet::Error)
      end

      it "should not accept hashes" do
          expect{
            @type.new(
              :source            => @valid_url,
              :path              => @valid_name,
              :ensure            => :present,
              :http_open_timeout => {'test' => 'test'},
            )
          }.to raise_error(Puppet::Error)
      end

      it "should not accept strings" do
          expect{
            @type.new(
              :source            => @valid_url,
              :path              => @valid_name,
              :ensure            => :present,
              :http_open_timeout => 'test',
            )
          }.to raise_error(Puppet::Error)
      end
    end
  end
end
