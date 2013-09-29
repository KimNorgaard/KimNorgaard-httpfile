require 'net/http'

# @todo look at https://github.com/haf/puppet-httpfile
# @todo support other checksum methods (sidecar files)
# @todo support other checksum types (sha)
# @todo support http post (with data)
# @todo better ssl support
# @todo better exception handling
Puppet::Type.type(:httpfile).provide(:ruby_net_http) do
  desc 'Manage files fetched via HTTP.'

  def create
    begin
      req = Net::HTTP::Get.new(@uri.request_uri)
      authorize!(req)
      @conn.request(req) do |res|
        fail "Failed to fetch file: #{resource[:source]} - #{res.code}" if res.code != '200'

        out_file = File.open("#{resource[:name]}",'wb')
        length   = res['Content-Length'].to_i
        prevprogress = done = 0
        res.read_body do |segment|
          out_file.write(segment)
          done += segment.length
          progress = (done.quo(length) * 100).to_i
          if resource[:print_progress] and progress > prevprogress
            notice "#{@uri.to_s}: #{progress.to_i}% (#{done}/#{length})"
          end
          prevprogress = progress
        end
        out_file.close()
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
           Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      fail "Failed to fetch file: #{resource[:source]} - #{e.message}"
    rescue Exception => e
      fail "Failed to fetch file: #{resource[:source]} - #{e.message}"
    end
  end

  def destroy
    File.unlink "#{resource[:name]}"
  end

  def exists?
    # Setup the http connection
    init_http

    # Check if the file exists
    return false unless File.exists? "#{resource[:name]}"

    # Check if checksum checking is disabled
    if resource[:force]
      notice "force option enabled - downloading file regardless of checksum."
      return false
    end

    # Get remote and local checksums
    remote_checksum = @head['Content-MD5']
    local_checksum  = get_local_checksum

    # Check support for Content-MD5
    fail "Server #{@uri.host}:#{@uri.port} does not support the Content-MD5 header." unless remote_checksum

    # Apache delivers Content-MD5 as a base64 digest. We are using hex.
    # @todo: it might be prudent to also check for endianness (unpack('h*'))
    remote_checksum = Base64.decode64(remote_checksum).unpack('H*').first

    # Check remote checksum against the expected one, if one is specified
    if resource[:expected_checksum] and resource[:expected_checksum] != remote_checksum
      fail "#{@uri.to_s} MD5 (#{remote_checksum}) differs from expected MD5 (#{resource[:expected_checksum]})."
    end

    # Check the remote checksum against the local one
    if local_checksum != remote_checksum
      notice "#{@uri.to_s} MD5 (#{remote_checksum}) differs from local MD5 (#{local_checksum}). Will fetch new file."
      return false
    end

    true
  end

  private

  # Setup the http connection
  def init_http
    @uri  = URI.parse(URI.escape(resource[:source]))
    @conn = Net::HTTP.new(@uri.host, @uri.port)
    @conn.open_timeout = resource[:http_open_timeout] || nil
    if @uri.scheme == 'https'
      @conn.use_ssl = true
      @conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    get_head
    @conn
  end

  # Get MD5 digest of local file
  def get_local_checksum
    md5 = Digest::MD5.new
    File.open(resource[:name], "rb") do |f|
      while (data = f.read(4096))
        md5 << data
      end
    end
    md5.hexdigest
  end

  # Get HTTP headers from specified URL
  def get_head
    init_http unless @conn
    begin
      req = Net::HTTP::Head.new(@uri.request_uri)
      authorize!(req)
      @head = @conn.request(req)
      fail "Failed to send HEAD to: #{resource[:source]} - #{@head.code}" if @head.code != '200'
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
           Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      fail "Failed to fetch file: #{resource[:source]} - #{e.message}"
    rescue Exception => e
      fail "Failed to fetch file: #{resource[:source]} - #{e.message}"
    end
    @head
  end

  # Set HTTP Basic Authentication
  def authorize!(req)
    req.basic_auth resource[:http_user], resource[:http_pass]
  end
end
