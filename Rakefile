# frozen_string_literal: true

require "rake/testtask"
require "rubygems/package_task"

Rake::TestTask.new do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
end

Gem::PackageTask.new(Gem::Specification.load("posh-bundler.gemspec")).define

desc "Build the gem in pkg/"
task build: :gem

task default: :test
