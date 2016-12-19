require 'pry'
require 'timecop'
Dir.glob(File.expand_path('../../lib/**/*.rb', __FILE__), &method(:require))

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on a real object.
    mocks.verify_partial_doubles = true
  end
  # Show 10 slowest examples
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies.
  # Debug order dependency problems running rspec with  '--seed 1234' option
  config.order = :random
  Kernel.srand config.seed
end

