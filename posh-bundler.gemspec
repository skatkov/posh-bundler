# frozen_string_literal: true

require_relative "lib/posh_bundler/version"

Gem::Specification.new do |spec|
  spec.name = "posh-bundler"
  spec.version = PoshBundler::VERSION
  spec.authors = ["Stanislav Katkov"]
  spec.email = ["contact@poshtui.com"]

  spec.summary = "Keep POSH documentation in sync after Bundler installs and updates."
  spec.description = "A best-effort Bundler plugin that runs posh sync once after " \
    "bundle install or bundle update, using the project's resolved dependencies."
  spec.homepage = "https://poshtui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "source_code_uri" => "https://github.com/skatkov/posh-bundler",
    "documentation_uri" => "https://poshtui.com/docs#automatic-sync-with-bundler-optional",
    "bug_tracker_uri" => "https://github.com/skatkov/posh-bundler/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) { Dir["lib/**/*.rb"] + %w[plugins.rb README.md LICENSE] }
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler", ">= 2.3.17", "< 5.0"
end
