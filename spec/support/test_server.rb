require 'digest/md5'
require 'webrick'

class TestServer
  def initialize
    server = WEBrick::HTTPServer.new(
      :Port => 12345,
      :Logger => WEBrick::Log.new("/dev/null"),
      AccessLog: [],
    )

    server.mount_proc '/test_ok' do |req, res|
      body = "test"
      checksum = Digest::MD5.new.base64digest(body)
      res['Content-MD5'] = checksum
      res.body = body
      res.status = 200
    end

    server.mount_proc '/test_ok.md5' do |req, res|
      res['Content-Type'] = 'text/plain'
      checksum = Digest::MD5.new.hexdigest('test')
      res.body = "MD5(ok_with_sidecar.md5)= #{checksum}"
      res.status = 200
    end

    server.mount_proc '/test_ok.sha1' do |req, res|
      res['Content-Type'] = 'text/plain'
      checksum = Digest::SHA1.new.hexdigest('test')
      res.body = "SHA1(ok_with_sidecar.md5)= #{checksum}"
      res.status = 200
    end

    trap('INT') { server.stop }
    server.start
  end
end
