require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage line: 100
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do
      SimpleCov.result
    end

    def recipe_fixture(name)
      file_fixture("recipes/#{name}.html").read
    end
  end
end
