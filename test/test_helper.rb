# frozen_string_literal: true

require "bundler"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "uri"
require "zlib"

class BundlerIntegrationTest < Minitest::Test
  PLUGIN_ROOT = File.expand_path("..", __dir__)

  def setup
    @directory = Dir.mktmpdir("posh bundler-")
    @project = File.join(@directory, "ruby project")
    @home = File.join(@directory, "home")
    @bin = File.join(@directory, "bin")
    @log = File.join(@directory, "sync.jsonl")
    FileUtils.mkdir_p([@project, @home, @bin])

    @environment = {
      "HOME" => @home,
      "BUNDLE_USER_HOME" => File.join(@home, ".bundle"),
      "BUNDLE_IGNORE_CONFIG" => "1",
      "BUNDLER_VERSION" => Bundler::VERSION,
      "PATH" => @bin,
      "POSH_AUTO_SYNC" => nil,
      "POSH_TEST_LOG" => @log
    }

    prepare_gem_repository
    write_fixture_gem("1.0.0")
    File.write(File.join(@project, "Gemfile"), <<~RUBY)
      source #{@source_url.inspect}
      gem "posh_fixture", path: "fixture"
    RUBY

    File.write(File.join(@bin, "posh"), <<~RUBY)
      #!#{RbConfig.ruby}
      require "json"

      entry = {
        "arguments" => ARGV,
        "lockfile" => File.read(File.join(ARGV.last, "Gemfile.lock")),
        "bundle_gemfile" => ENV["BUNDLE_GEMFILE"],
        "rubyopt" => ENV["RUBYOPT"]
      }
      File.open(ENV.fetch("POSH_TEST_LOG"), "a") do |file|
        file.puts(JSON.generate(entry))
      end
      exit ENV.fetch("POSH_TEST_EXIT", "0").to_i
    RUBY
    File.chmod(0o755, File.join(@bin, "posh"))
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  private

  def prepare_gem_repository
    repository = File.join(@directory, "repository")
    gems = File.join(repository, "gems")
    FileUtils.mkdir_p(gems)

    spec = Gem::Specification.load(File.join(PLUGIN_ROOT, "posh-bundler.gemspec"))
    Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
      Dir.chdir(PLUGIN_ROOT) { Gem::Package.build(spec, false, false, File.join(gems, spec.file_name)) }
    end

    # A minimal static RubyGems repository keeps every Bundler version offline.
    quick = File.join(repository, "quick", "Marshal.4.8")
    FileUtils.mkdir_p(quick)
    File.binwrite(File.join(quick, "#{spec.full_name}.gemspec.rz"), Zlib::Deflate.deflate(Marshal.dump(spec)))
    versions = [[spec.name, spec.version, "ruby"]]
    {"specs" => versions, "latest_specs" => versions, "prerelease_specs" => []}.each do |name, entries|
      Zlib::GzipWriter.open(File.join(repository, "#{name}.4.8.gz")) do |file|
        file.write(Marshal.dump(entries))
      end
    end

    @source_url = URI::DEFAULT_PARSER.escape("file://#{repository}")
  end

  def write_fixture_gem(version)
    directory = File.join(@project, "fixture")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "posh_fixture.gemspec"), <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = "posh_fixture"
        spec.version = #{version.inspect}
        spec.summary = "Local fixture for POSH Bundler tests"
        spec.authors = ["POSH"]
        spec.files = []
      end
    RUBY
  end

  def bundle(*arguments, environment: {}, directory: @project)
    # User-installed RubyGems plugins (for example version-manager reshim hooks)
    # must not run in our fixtures. Bundler's own plugin system stays enabled.
    bootstrap = <<~RUBY
      require "rubygems"
      Gem.define_singleton_method(:load_plugins) {}
      Gem.define_singleton_method(:load_env_plugins) {}
      load ARGV.shift
    RUBY

    Bundler.with_unbundled_env do
      Open3.capture3(
        @environment.merge(environment),
        RbConfig.ruby,
        "-e", bootstrap,
        Gem.bin_path("bundler", "bundle", Bundler::VERSION),
        *arguments,
        chdir: directory
      )
    end
  end

  def assert_bundle_success(*arguments, **options)
    output, errors, status = bundle(*arguments, **options)
    assert status.success?, "bundle #{arguments.join(" ")} failed:\n#{output}\n#{errors}"
    [output, errors]
  end

  def install_plugin(**options)
    assert_bundle_success("plugin", "install", "posh-bundler", "--source", @source_url, **options)
    assert_empty syncs, "Installing the plugin itself must not sync docs"
  end

  def syncs
    return [] unless File.exist?(@log)

    File.readlines(@log).map { |line| JSON.parse(line) }
  end
end
