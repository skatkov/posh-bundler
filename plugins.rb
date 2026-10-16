# frozen_string_literal: true

require "bundler/plugin/api"
require "posh_bundler"

Bundler::Plugin::API.hook("after-install-all") do |_dependencies|
  PoshBundler.sync
end
