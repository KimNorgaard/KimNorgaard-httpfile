require 'puppet/type'
require 'uri'

Puppet::Type.newtype(:httpfile) do
  @doc = <<-'EOT'
    Fetch a file using HTTP(S). Basic usage:

    httpfile { '/path/to/file.ext':
      path                      => '/path/to/file.ext',
      source                    => 'http://example.com/my_file.bin',
      expected_checksum         => 'b96af7576939a17ac4b2d4b6edb50ce7',
      http_user                 => 'foo',
      http_pass                 => 'bar',
    }
  EOT

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:path, :namevar => true) do
    desc 'The destination path (including file name). Must be fully qualified.'
    isrequired

    validate do |value|
      fail Puppet::Error, "File path must be set to something." % value if value.empty?
      unless Puppet::Util.absolute_path?(value)
        fail "File path '%s' is not fully qualified." % value
      end
    end
  end

  newparam(:source) do
    desc 'The url of the file to be fetched. http and https are supported.'
    isrequired

    validate do |source|
      begin
        uri = URI.parse(URI.escape(source))
      rescue => detail
        fail "Invalid URL #{source}: #{detail}"
      end

      fail "Cannot use relative URLs '#{source}'" unless uri.absolute?
      fail "Cannot use opaque URLs '#{source}'" unless uri.hierarchical?
      unless %w{http https}.include?(uri.scheme)
        fail "Cannot use URLs of type '#{uri.scheme}' as source for fileserving"
      end
    end

    munge do |source|
      URI.parse(URI.escape(source))
    end
  end

  newparam(:force, :boolean => true) do
    desc 'Always download the file. Default: false.'
    newvalues :true, :false
    defaultto false
  end

  newparam(:print_progress, :boolean => true) do
    desc 'Whether to print download progress or not. Default: false.'
    newvalues :true, :false
    defaultto false
  end

  newparam(:checksum_type) do
    desc <<-'EOT'
      The checksum type to use. Currenly only content_md5 is supported.
      Possible values are:
      
      * content_md5  (32 bytes hex digest) - Content-MD5 header is used
      * sidecar_md5  (32 bytes hex digest) - sidecar md5 file is used
      * sidecar_sha1 (40 bytes hex digest) - sidecar sha1 file is used
      
      Default: content_md5'
    EOT

    newvalues :content_md5, :sidecar_md5, :sidecar_sha1
    defaultto :content_md5
  end

  newparam(:sidecar_source) do
    desc <<-'EOT'
      Sidecar URL to use for fetching the expected checksum. If this
      parameter is not specified, it is assumed that the sidecar file
      is placed next to :source and is named with an appropriate
      extension (e.g. .md5 for sidecar_md5).
    EOT

    validate do |source|
      begin
        uri = URI.parse(URI.escape(source))
      rescue => detail
        fail "Invalid URL #{source}: #{detail}"
      end

      fail "Cannot use relative URLs '#{source}'" unless uri.absolute?
      fail "Cannot use opaque URLs '#{source}'" unless uri.hierarchical?
      unless %w{http https}.include?(uri.scheme)
        fail "Cannot use URLs of type '#{uri.scheme}' as source for fileserving"
      end
    end

    munge do |source|
      URI.parse(URI.escape(source))
    end
  end

  [:sidecar_http_request_body, :sidecar_http_request_content_type,
   :sidecar_http_user, :sidecar_http_pass].each do |parm|
     newparam(parm)
  end

  newparam(:expected_checksum) do
    desc 'The exptected checksum of the file.'
  end

  newparam(:sidecar_http_verb) do
    desc 'The HTTP verb to use for sidecar files (get or post). Default: :http_verb value.'
    newvalues :get, :post
  end

  newparam(:http_verb) do
    desc 'The HTTP verb to use (get or post). Default: get.'
    newvalues :get, :post
    defaultto :get
  end

  newparam(:http_ssl_verify, :boolean => true) do
    desc 'Enable/disable HTTPS Certificate Verification. Default: true.'
    newvalues :true, :false
    defaultto true
  end

  newparam(:http_ssl_ca_file) do
    desc 'Sets path of a CA certification file in PEM format.'
  end

  newparam(:http_ssl_ca_path) do
    desc 'Sets path of a CA certification directory containing ' +
         'certifications in PEM format'
  end

  newparam(:http_request_content_type) do
    desc 'HTTP Request Content Type.'
  end

  newparam(:http_request_headers) do
    desc 'HTTP Request Headers (Hash).'
    validate do |value|
      fail "http_request_headers must be a Hash" unless value.is_a?(Hash)
    end
    defaultto {}
  end 

  newparam(:sidecar_http_request_headers) do
    desc 'HTTP Request Headers of sidecar file (Hash).'
    validate do |value|
      fail "http_request_headers must be a Hash" unless value.is_a?(Hash)
    end
    defaultto {}
  end 

  newparam(:http_request_body) do
    desc 'HTTP Request Body.'
  end

  newparam(:http_post_form_data) do
    desc 'HTTP POST Form Data (hash). Only used when setting http_vers to :post.'
    validate do |value|
      fail "http_post_form_data must be a Hash" unless value.is_a?(Hash)
    end
    defaultto {}
  end

  newparam(:sidecar_http_post_form_data) do
    desc 'HTTP POST Form Data (hash) of sidecar file. Only used when setting http_vers to :post.'
    validate do |value|
      fail "http_post_form_data must be a Hash" unless value.is_a?(Hash)
    end
    defaultto {}
  end

  newparam(:http_open_timeout) do
    desc <<-'EOT'
      Number of seconds to wait for the connection to open.
      
      Default: none
    EOT

    validate do |value|
      fail "Not an integer: '%s'." % value unless value.is_a?(Integer)
    end
  end

  newparam(:http_user) do
    desc 'HTTP Basic Auth User.'
  end

  newparam(:http_pass) do
    desc 'HTTP Basic Auth Password.'
  end

  validate do
    # http://projects.puppetlabs.com/issues/4049
    raise ArgumentError, 'httpfile: source is required' unless self[:source]
    raise ArgumentError, 'httpfile: path is required' unless self[:path]

    if self[:expected_checksum]
      case self[:checksum_type]
      when :content_md5, :sidecar_md5
        unless self[:expected_checksum].match(/^[0-9a-f]{32}$/)
          fail "Not a MD5 hex digest: '%s'." % self[:expected_checksum]
        end
      when :sidecar_sha1
        unless self[:expected_checksum].match(/^[0-9a-f]{40}$/)
          fail "Not a SHA1 hex digest: '%s'." % self[:expected_checksum]
        end
      end
    end
  end

end
