require 'rake'
require 'rspec/core/rake_task'

[:spec, :test].each do |test|
  RSpec::Core::RakeTask.new(test) do |t|
    t.rspec_opts = ['-O spec/spec.opts']
    t.pattern = 'spec/{unit}/**/*_spec.rb'
  end
end
