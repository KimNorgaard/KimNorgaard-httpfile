require 'net/http'

Puppet::Type.type(:httpfile).provide(:ruby_net_http) do
  desc 'Manage files fetched via HTTP.'

  def create
    begin
      req = http_request(resource[:http_verb], resource[:source])
      notice "Downloading #{resource[:source]}"
      conn.request(req) do |res|
        fail "#{resource[:http_verb].to_s.upcase} #{resource[:source]} " +
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
    return true if File.exists?("#{resource[:name]}") and
                  resource[:ensure] == :absent

    # Check if checksum checking is disabled
    if resource[:force] == true
      notice "force option enabled - downloading file regardless of checksum."
      return false
    end


    # Check if the expected checksum matches the local one
    return true if File.exists?("#{resource[:name]}") and
                  resource[:expected_checksum] and
                  resource[:expected_checksum] == local_checksum
    return false if File.exists?("#{resource[:name]}") and
                  resource[:expected_checksum] and
                  resource[:expected_checksum] != local_checksum

    # Check the remote checksum against the local one
    if local_checksum != remote_checksum
      notice "#{resource[:source]} checksum (#{remote_checksum}) != #{resource[:path]} " +
             "checksum (#{local_checksum}). Will fetch new file."
      return false
    end

    true
  end

  #private

  # Get HTTP connection
  def conn
    return @conn if defined?(@conn)
    @conn = Net::HTTP.new(resource[:source].host, resource[:source].port)
    @conn.open_timeout = resource[:http_open_timeout] || nil
    if resource[:source].scheme == 'https'
      @conn.use_ssl = true
      @conn.ca_path = resource[:http_ssl_ca_path] if resource[:http_ssl_ca_path]
      @conn.ca_file = resource[:http_ssl_ca_file] if resource[:http_ssl_ca_file]
      @conn.cert = OpenSSL::X509::Certificate.new(File.read(resource[:http_ssl_cert])) if resource[:http_ssl_cert]
      @conn.key = OpenSSL::PKey::RSA.new(File.read(resource[:http_ssl_key])) if resource[:http_ssl_key]
      @conn.verify_mode = if resource[:http_ssl_verify] == true
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
      @head = conn.request(http_request(:head, resource[:source]))
      fail "#{resource[:http_verb].to_s.upcase} #{resource[:source]} " +
           "returned #{@head.code}" unless @head.code == '200'
    rescue Exception => e
      fail "Failed to fetch file: #{resource[:source]} - #{e.message}"
    end
    @head
  end

  # Send a HTTP request
  def http_request(verb, uri, options = {})
    opts = {
      :form_data    => resource[:http_post_form_data],
      :body         => resource[:http_request_body],
      :headers      => resource[:http_request_headers],
      :content_type => resource[:http_request_content_type],
      :http_user    => resource[:http_user],
      :http_pass    => resource[:http_pass],
    }.merge(options)

    case verb.to_sym
    when :head
      req = Net::HTTP::Head.new(uri.request_uri)
    when :get
      req = Net::HTTP::Get.new(uri.request_uri)
    when :post
      req = Net::HTTP::Post.new(uri.request_uri)
    end
    (opts[:headers] || {}).each do |header, value|
      req[header] = value
    end
    req.body = opts[:body]
    req.content_type = opts[:content_type] || ''
    if not opts[:http_user].nil? or not opts[:http_pass].nil?
      req.basic_auth opts[:http_user], opts[:http_pass]
    end
    req.set_form_data(opts[:form_data] || {}) if verb.to_sym == :post
    req
  end

  # Get local checksum
  def local_checksum
    return @local_checksum if defined?(@local_checksum)
    @local_checksum = case resource[:checksum_type]
      when :content_md5, :sidecar_md5
        checksum = Digest::MD5.new
        File.open(resource[:name], "rb") do |f|
          while (data = f.read(4096))
            checksum << data
          end
        end
        checksum.hexdigest
      when :sidecar_sha1
        checksum = Digest::SHA1.new
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
        fail "Server #{resource[:source].host}:#{resource[:source].port} does " +
             "not support the Content-MD5 header." unless checksum

        # Apache delivers Content-MD5 as a base64 digest. We are using hex.
        # @todo: it might be prudent to also check for endianness (unpack('h*'))
        Base64.decode64(checksum).unpack('H*').first
      when :sidecar_md5, :sidecar_sha1
        ext  = resource[:checksum_type].to_s.split('_').last
        url  = resource[:sidecar_source] || URI.parse("#{resource[:source]}.#{ext}")
        verb = resource[:sidecar_http_verb] || resource[:http_verb]
        request_opts = {
          :form_data    => resource[:sidecar_http_post_form_data] || resource[:http_post_form_data],
          :body         => resource[:sidecar_http_request_body] || resource[:http_request_body],
          :headers      => resource[:sidecar_http_request_headers] || resource[:http_request_headers],
          :content_type => resource[:sidecar_http_request_content_type] || resource[:http_request_content_type],
          :http_user    => resource[:sidecar_http_user] || resource[:http_user],
          :http_pass    => resource[:sidecar_http_pass] || resource[:http_pass],
        }
        req  = http_request(verb, url, request_opts)
        res  = conn.request(req)
        fail "Failed to fetch sidecar file. #{verb.to_s.upcase} #{url} " +
             "returned #{res.code}" unless res.code == '200'
        first_line = res.body.lines.first
        # format example: "MD5(/path/to/file)= checksum"
        match = first_line.match(/^(MD5|SHA1)\(.+\)= ([0-9a-f]+)$/i)
        debug "#{url} - first line was: #{first_line}"
        fail "failed to read checksum from #{url} - it should match: /^(MD5|SHA1)\\(.+\\)= ([0-9a-f]+)$/i" unless match
        match[2]
    end
  end
end
