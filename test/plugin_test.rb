# frozen_string_literal: true

require "test_helper"

class PluginTest < BundlerIntegrationTest
  def test_install_syncs_once_with_the_written_lockfile_and_correct_project
    install_plugin

    _, errors = assert_bundle_success("install", "--local")

    assert_equal 1, syncs.length
    assert_equal ["sync", "--project", @project], syncs.first.fetch("arguments")
    assert_includes syncs.first.fetch("lockfile"), "posh_fixture (1.0.0)"
    assert_equal File.read(File.join(@project, "Gemfile.lock")), syncs.first.fetch("lockfile")
    refute_includes errors, "POSH:"
  end

  def test_a_no_op_install_still_syncs_once
    install_plugin
    2.times { assert_bundle_success("install", "--local") }

    assert_equal 2, syncs.length
  end

  def test_update_syncs_with_the_newly_resolved_version
    install_plugin
    assert_bundle_success("install", "--local")
    write_fixture_gem("2.0.0")

    assert_bundle_success("update", "--all", "--local")

    assert_equal 2, syncs.length
    assert_includes syncs.first.fetch("lockfile"), "posh_fixture (1.0.0)"
    assert_includes syncs.last.fetch("lockfile"), "posh_fixture (2.0.0)"
  end

  def test_targeted_update_also_syncs
    install_plugin
    assert_bundle_success("install", "--local")
    write_fixture_gem("2.0.0")

    assert_bundle_success("update", "posh_fixture", "--local")

    assert_equal 2, syncs.length
    assert_includes syncs.last.fetch("lockfile"), "posh_fixture (2.0.0)"
  end

  def test_sync_runs_outside_bundlers_modified_ruby_environment
    install_plugin
    library = File.dirname(Bundler.method(:setup).source_location.first)
    setup = File.join(library, "bundler", "setup")
    assert_bundle_success("install", "--local", environment: {"RUBYOPT" => "-r#{setup}"})

    assert_equal 1, syncs.length
    assert_nil syncs.first.fetch("bundle_gemfile")
    refute_includes syncs.first.fetch("rubyopt").to_s, "bundler/setup"
  end

  def test_invoking_bundler_from_a_subdirectory_uses_the_project_root
    install_plugin
    directory = File.join(@project, "app")
    FileUtils.mkdir_p(directory)

    assert_bundle_success("install", "--local", directory: directory)

    assert_equal 1, syncs.length
    assert_equal ["sync", "--project", @project], syncs.first.fetch("arguments")
  end

  def test_a_failed_sync_warns_without_failing_bundler
    install_plugin

    _, errors = assert_bundle_success("install", "--local", environment: {"POSH_TEST_EXIT" => "1"})

    assert_equal 1, syncs.length
    assert_includes errors, "POSH: documentation sync failed"
    assert_includes errors, "Run `posh sync` to retry."
    assert File.exist?(File.join(@project, "Gemfile.lock"))
  end

  def test_a_missing_executable_warns_without_failing_bundler
    install_plugin
    File.delete(File.join(@bin, "posh"))

    _, errors = assert_bundle_success("install", "--local")

    assert_empty syncs
    assert_includes errors, "POSH: documentation sync failed"
    assert_includes errors, "Run `posh sync` to retry."
  end

  def test_an_unexecutable_binary_warns_without_failing_bundler
    install_plugin
    File.chmod(0o644, File.join(@bin, "posh"))

    _, errors = assert_bundle_success("install", "--local")

    assert_empty syncs
    assert_includes errors, "POSH: documentation sync failed"
  end

  def test_the_environment_opt_out_skips_sync
    install_plugin

    _, errors = assert_bundle_success("install", "--local", environment: {"POSH_AUTO_SYNC" => "0"})

    assert_empty syncs
    refute_includes errors, "POSH:"
  end

  def test_other_environment_values_do_not_disable_sync
    install_plugin
    assert_bundle_success("install", "--local", environment: {"POSH_AUTO_SYNC" => "1"})

    assert_equal 1, syncs.length
  end

  def test_a_failed_dependency_install_does_not_sync
    install_plugin
    File.write(File.join(@project, "Gemfile"), <<~RUBY)
      source #{@source_url.inspect}
      gem "posh_fixture", ">= 9", path: "fixture"
    RUBY

    _, _, status = bundle("install", "--local")

    refute status.success?
    assert_empty syncs
  end

  def test_other_bundler_commands_do_not_sync
    install_plugin
    assert_bundle_success("install", "--local")

    assert_bundle_success("check")
    assert_bundle_success("lock", "--local")

    assert_equal 1, syncs.length
  end

  def test_global_plugin_installation_also_works
    install_plugin(directory: @home)
    assert_bundle_success("install", "--local")

    assert_equal 1, syncs.length
    assert_equal ["sync", "--project", @project], syncs.first.fetch("arguments")
  end

  def test_a_gemfile_plugin_directive_registers_the_hook_on_the_first_install
    File.open(File.join(@project, "Gemfile"), "a") do |file|
      file.puts('plugin "posh-bundler"')
    end

    assert_bundle_success("install", "--local")

    assert_equal 1, syncs.length
    assert_includes syncs.first.fetch("lockfile"), "posh_fixture (1.0.0)"
  end

  def test_uninstalling_the_plugin_disables_automatic_sync
    install_plugin
    assert_bundle_success("plugin", "uninstall", "posh-bundler")
    assert_bundle_success("install", "--local")

    assert_empty syncs
  end
end
