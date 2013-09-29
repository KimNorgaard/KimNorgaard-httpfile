require 'puppet/type'
require 'puppet/parameter/boolean'
require 'uri'

Puppet::Type.newtype(:httpfile) do
  @doc = <<-'EOT'
    Fetch a file using HTTP(S). Usage:

    httpfile { '/path/to/file.ext':
      path              => '/path/to/file.ext',
      source            => 'http://example.com/my_file.bin',
      force             => false,
      checksum_type     => 'md5',
      expected_checksum => 'b96af7576939a17ac4b2d4b6edb50ce7',
      http_open_timeout => 5,
      http_user         => 'foo',
      http_pass         => 'bar',
    }
  EOT

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:path, :namevar => true) do
    desc 'The destination path (including file name). Must be fully qualified.'

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        fail "File paths must be fully qualified, not '#{value}'."
      end
    end
  end

  newparam(:source) do
    desc 'The url of the file to be fetched. http and https are supported.'

    validate do |source|
      begin
        uri = URI.parse(URI.escape(source))
      rescue => detail
        fail "Invalid URL #{source}: #{detail}"
      end

      fail "Cannot use relative URLs '#{source}'" unless uri.absolute?
      fail "Cannot use opaque URLs '#{source}'" unless uri.hierarchical?
      fail "Cannot use URLs of type '#{uri.scheme}' as source for fileserving" unless %w{http https}.include?(uri.scheme)
    end

    isrequired
  end

  newparam(:force, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc 'Always download the file. Default: false.'
    defaultto false
  end

  newparam(:print_progress, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc 'Whether to print download progress or not. Default: false.'
    defaultto false
  end

  newparam(:checksum_type) do
    desc <<-'EOT'
      The checksum type to use. Currenly only md5 is supported.
      Possible values are:
      
      * md5 (32 bytes hex digest)
      
      Default: md5'
    EOT

    newvalues :md5
    defaultto :md5
  end

  newparam(:expected_checksum) do
    desc 'The exptected MD5 hex digest of the file.'

    validate do |value|
      fail "Not a MD5 hex digest: '#{value}'." unless value =~ /^[0-9a-f]{32}$/
    end
  end

  newparam(:http_open_timeout) do
    desc <<-'EOT'
      Number of seconds to wait for the connection to open.
      
      Default: none
    EOT

    validate do |value|
      fail "Not an integer: '#{value}'." unless value.is_a?(Integer)
    end
  end

  newparam(:http_user) do
    desc 'HTTP Basic Auth User.'
  end

  newparam(:http_pass) do
    desc 'HTTP Basic Auth Password.'
  end
end
