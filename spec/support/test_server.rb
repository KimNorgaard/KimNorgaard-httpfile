require 'digest/md5'
require 'webrick'

class TestServer
  def initialize
    server = WEBrick::HTTPServer.new :Port => 1234

    server.mount_proc '/test_with_content_md5' do |req, res|
      body = "test1234"
      checksum = Digest::MD5.new.base64digest(body)
      res['Content-MD5'] = checksum
      res.body = body
      res.status = 200
    end

    trap('INT') { server.stop }
    server.start
  end
end
