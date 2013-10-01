Dir["./spec/support/**/*.rb"].each {|f| require f} 

require 'rubygems'
require 'puppetlabs_spec_helper/module_spec_helper'

@test_server_thread = Thread.new do
  TestServer.new
end
sleep(1)

RSpec.configure do |config|
  config.mock_with :mocha
end
