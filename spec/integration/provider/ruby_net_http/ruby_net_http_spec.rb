require 'spec_helper'

describe Puppet::Type.type(:httpfile).provider(:ruby_net_http), '(integration)' do
  include PuppetlabsSpec::Files

  # check that ensure present works
  #   - that the file is downloaded if it doesn't exist
  #   - that the file is updated if it exists
  #     o using all three checksum types
  #     o using https source?
  #     o using basic auth
  #     o using different http verbs
  #     o using sidecar_source
  #     o using sidecar_source with https
  #     o using http options
  #     o open timeout using sleep perhaps?
  #     o using different sidecar verbs
  #     o using different sidecar options
  #     o using expeced checksum - hmmm?
  #   - that the file is downloaded no matter what using :force
  # check that ensure absent works
  #   - that it removes the file if it exists
  # mark following tests as pending:
  #   - ssl certificate testing
  #   - 
end
