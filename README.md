# Capistrano::GitCopy

Creates a tar archive locally from the git repository and uploads it to the remote server.

## Setup

Add the library to your `Gemfile`:

```ruby
group :development do
  gem 'capistrano-git-copy', require: false
end
```

And require it in your `Capfile`:

```ruby
require 'capistrano/git_copy'
install_plugin Capistrano::GitCopy::SCM
```

### Submodules
By default, it includes all submodules into the deployment package. However,
if they are not needed in a particular deployment, you can disable them with
a configuration option:
```ruby
set :with_submodules, false
```
Besides using `export-ignore` in `.gitattributes` it's possible exclude files and directories by
adding them to `git_excludes`:
```ruby
append :git_excludes, 'config/database.yml.example', 'test', 'rspec'
```
**git-archive-all does not support .gitattributes yet - please set with_submodules to false to make e.g. export-ignore work**

### Subdirectories

It is also possible to deploy only a subdirectory to the remote server:
```ruby
set :upload_path, 'dist'
```
This makes it possible to compile or build something locally and only upload the result
```ruby
namespace :deploy do
  before :'git_copy:create_release', :'deploy:build_app'

  task :build_app do
    run_locally do
      within(fetch(:git_copy_plugin).repo_cache_path) do
        execute :npm, :install
        execute :npm, :run, :'build-dist'
      end
    end
  end
end
```

## Notes

* Uses [git-archive-all](https://github.com/Kentzo/git-archive-all) for bundling repositories.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
