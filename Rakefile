require 'rake'
require 'rspec/core/rake_task'

task :test => [:spec]

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['-O spec/spec.opts']
  t.pattern = 'spec/{unit,integration}/**/*_spec.rb'
end
