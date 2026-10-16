# posh-bundler

Automatically run [`posh sync`](https://poshtui.com) after `bundle install` and
`bundle update`, so your local Ruby and gem documentation follows your project's
resolved dependencies.

This is an optional **local-development tool**. Install it on your development
machine; it is not needed to run or deploy your application, or in CI.

## Requirements

- Ruby 2.7 or newer and Bundler >= 2.3.17, < 5.0.
- The POSH executable installed separately and available on your `PATH`.
- A Ruby project with a `Gemfile` and `Gemfile.lock`.

This gem is a small Bundler plugin, not the POSH executable. See the
[POSH setup guide](https://poshtui.com/docs) to install POSH.

## Enable automatic sync

On your development machine, from the Ruby project where you want automatic sync:

```sh
bundle plugin install posh-bundler
```

Bundler installs the plugin locally when you run this inside a project. To enable
it for all of your projects, run the command outside any directory containing a
Gemfile, including its parent directories. Global plugins are scoped to your
user and Bundler's plugin configuration, not every Ruby installation on a machine.

After enabling it, use Bundler normally:

```sh
bundle install
bundle update
bundle update rails
```

The plugin runs `posh sync --project /path/to/project` once after the installer
succeeds and writes the lockfile. It also runs when all dependencies are already
installed. POSH reuses installed docsets; syncing still uses the network and runs
synchronously, so Bundler waits for it to finish.

If POSH is missing, cannot download docs, or exits unsuccessfully, the plugin
prints a warning and leaves Bundler's installation successful. Retry manually
with `posh sync`. Failed dependency installations do not trigger a sync.

The plugin does not add an application dependency or change your Gemfile. Do not
add it with `gem "posh-bundler"`: Bundler plugins need explicit installation.
For a shared, project-level opt-in, Bundler also supports this Gemfile directive:

```ruby
plugin "posh-bundler"
```

That installs and registers the plugin when contributors run `bundle install`.
They still need to install POSH separately. The directive is not automatically
limited to development: prefer the per-developer installation command above if
you do not want Bundler to install the plugin in CI or production.

## Disable or remove

Skip automatic sync for one command, for example while offline, in CI, or during
a production deployment:

```sh
POSH_AUTO_SYNC=0 bundle install
```

If the plugin is present in CI or production, set `POSH_AUTO_SYNC=0` in those
environments. The plugin does not detect development or production automatically.
This skips syncing; Bundler can still install a plugin declared in the Gemfile.
Only the exact value `0` disables the hook. Manual `posh sync` commands are unaffected.

Remove a locally installed plugin from the project where you installed it:

```sh
bundle plugin uninstall posh-bundler
```

For a global installation, uninstall from outside a project. If you declared the
plugin in your Gemfile, remove that directive too, or Bundler will reinstall it.

## Scope

The plugin uses Bundler's project root even when Bundler is invoked from a
subdirectory, and starts POSH outside Bundler's modified Ruby environment. It
targets the standard `Gemfile.lock` that POSH discovers in that project.

It does not run after `bundle lock`, `git pull`, or a branch switch. Run
`posh sync` manually after those operations if your dependencies changed.

## Development

```sh
bundle install
bundle exec rake test
bundle exec standardrb
bundle exec rake build
```

Tests use isolated temporary projects and a fake POSH executable. They exercise
real Bundler plugin installation, dependency installation, and updates without
network access or changing your user-level plugin configuration.

With Bundler 4, you can try the plugin in another project before publishing it:

```sh
bundle plugin install posh-bundler --path /absolute/path/to/posh-bundler
```

Bundler runs a path-installed plugin directly from that directory. Reinstall it
after changing hook registrations in `plugins.rb`.

## Releasing

Set the release version in `lib/posh_bundler/version.rb` and commit all changes.
Then run:

```sh
bundle exec rake test
bundle exec standardrb
bundle exec rake release
```

The release task uses Bundler's standard gem tasks. It builds the gem in `pkg/`,
checks for uncommitted changes, creates a `vVERSION` tag (for example, `v0.1.0`),
pushes the current branch and tag to its Git remote, and publishes the gem to
RubyGems. You need Git push access and RubyGems authentication with MFA enabled.

To build the gem without tagging, pushing, or publishing, use
`bundle exec rake build` instead.

## License

[MIT](LICENSE).
