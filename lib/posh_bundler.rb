# frozen_string_literal: true

require_relative "posh_bundler/version"

module PoshBundler
  def self.sync
    return if ENV["POSH_AUTO_SYNC"] == "0"

    project = Bundler.root.to_s

    Bundler.with_unbundled_env do
      system("posh", "sync", "--project", project, exception: true)
    end
  rescue => error
    Bundler.ui.warn("POSH: documentation sync failed (#{error.message}). Run `posh sync` to retry.")
  end
end
