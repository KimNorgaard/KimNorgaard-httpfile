require 'net/http'

Puppet::Type.type(:httpfile).provide(:ruby_net_http) do
  desc 'Manage files fetched via HTTP.'

  def create
    begin
      req = http_request(resource[:http_verb])
      conn.request(req) do |res|
        fail "#{resource[:http_verb].upcase} #{resource[:source]} " +
             "returned #{res.code}" unless res.code == '200'

        out_file = File.open("#{resource[:name]}",'wb')
        length = res['Content-Length'] && res['Content-Length'].to_i || 0
        prevprogress = done = 0
        print_progress = resource[:print_progress] and length > 0
        res.read_body do |segment|
          out_file.write(segment)
          done += segment.length
          progress = (done.quo(length) * 100).to_i
          if print_progress and progress > prevprogress
            notice "#{resource[:source]}: #{progress.to_i}% (#{done}/#{length})"
          end
          prevprogress = progress
        end
        out_file.close()
      end
    rescue Exception => e
      fail "Failed to fetch file: #{resource[:source]} - #{e.message}"
    end
  end

  def destroy
    File.unlink "#{resource[:name]}"
  end

  def exists?
    # Check if the file exists
    return false unless File.exists? "#{resource[:name]}"

    # Check if checksum checking is disabled
    if resource[:force]
      notice "force option enabled - downloading file regardless of checksum."
      return false
    end

    # Check remote checksum against the expected one, if one is specified
    if resource[:expected_checksum] and resource[:expected_checksum] != remote_checksum
      fail "#{resource[:source]} checksum (#{remote_checksum}) != expected " +
           "checksum (#{resource[:expected_checksum]})."
    end

    # Check the remote checksum against the local one
    if local_checksum != remote_checksum
      notice "#{resource[:source]} checksum (#{remote_checksum}) != #{resource[:path]} " +
             "checksum (#{local_checksum}). Will fetch new file."
      return false
    end

    true
  end

  private

  # Get HTTP connection
  def conn
    return @conn if defined?(@conn)
    @conn = Net::HTTP.new(resource[:source].host, resource[:source].port)
    @conn.open_timeout = resource[:http_open_timeout] || nil
    if resource[:source].scheme == 'https'
      @conn.use_ssl = true
      @conn.ca_path = resource[:http_ssl_ca_path] if resource[:http_ssl_ca_path]
      @conn.ca_file = resource[:http_ssl_ca_file] if resource[:http_ssl_ca_file]
      @conn.verify_mode = if resource[:http_ssl_verify]
        OpenSSL::SSL::VERIFY_PEER
      else
        OpenSSL::SSL::VERIFY_NONE
      end
      @conn.verify_depth = 5
    end
    @conn
  end

  # Get HTTP headers from specified URL
  def http_head
    return @head if defined?(@head)
    begin
      @head = conn.request(http_request(:head))
      fail "#{resource[:http_verb].upcase} #{resource[:source]} " +
           "returned #{@head.code}" unless @head.code == '200'
    rescue Exception => e
      fail "Failed to fetch file: #{resource[:source]} - #{e.message}"
    end
    @head
  end

  # Send a HTTP request
  def http_request(verb)
    case verb.to_sym
    when :head
      req = Net::HTTP::Head.new(resource[:source].request_uri)
    when :get
      req = Net::HTTP::Get.new(resource[:source].request_uri)
    when :post
      req = Net::HTTP::Post.new(resource[:source].request_uri)
      req.set_form_data(resource[:http_post_form_data] || {})
    end
    (resource[:http_request_headers] || {}).each do |header, value|
      req[header] = value
    end
    req.body = resource[:http_request_body]
    req.content_type = resource[:http_request_content_type] || ''
    req.basic_auth resource[:http_user], resource[:http_pass]
    req
  end

  # Get local checksum
  def local_checksum
    return @local_checksum if defined?(@local_checksum)
    @local_checksum = case resource[:checksum_type]
      when :content_md5
        checksum = Digest::MD5.new
        File.open(resource[:name], "rb") do |f|
          while (data = f.read(4096))
            checksum << data
          end
        end
        checksum.hexdigest
    end
  end

  # Get remote checksum
  def remote_checksum
    return @remote_checksum if defined?(@remote_checksum)
    @remote_checksum = case resource[:checksum_type]
      when :content_md5
        checksum = http_head['Content-MD5']

        # Check support for Content-MD5
        fail "Server #{resource[:source].host}:#{resource[:source].port} does not support the Content-MD5 " +
          "header." unless checksum

        # Apache delivers Content-MD5 as a base64 digest. We are using hex.
        # @todo: it might be prudent to also check for endianness (unpack('h*'))
        Base64.decode64(checksum).unpack('H*').first
    end
  end
end
