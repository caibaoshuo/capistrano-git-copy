# frozen_string_literal: true

require 'tmpdir'
require 'capistrano/scm/plugin'
require 'capistrano/git_copy/scm_helpers'

module Capistrano
  module GitCopy
    # SCM plugin for capistrano
    # uses a local clone and uploads a tar archive to the server
    class SCM < ::Capistrano::SCM::Plugin
      include Capistrano::GitCopy::SCMHelpers

      # set default values
      def set_defaults
        set_if_empty :with_clean, true
        set_if_empty :with_submodules, true
        set_if_empty :git_excludes,    []
        set_if_empty :upload_path,     '.'
      end

      # define plugin tasks
      def define_tasks
        eval_rakefile File.expand_path('tasks/git_copy.rake', __dir__)
      end

      # register capistrano hooks
      def register_hooks
        after  'deploy:new_release_path',     'git_copy:create_release'
        before 'deploy:check',                'git_copy:check'
        before 'deploy:set_current_revision', 'git_copy:set_current_revision'
      end

      # Check if repository is accessible
      #
      # @return void
      def check
        git(:'ls-remote --heads', repo_url)
      end

      # Check if repository cache exists and is valid
      #
      # @return [Boolean] indicates if repo cache exists
      def test
        if backend.test("[ -d #{repo_cache_path} ]")
          check_repo_cache_path
        else
          false
        end
      end

      # Clone repo to cache
      #
      # @return void
      def clone
        backend.execute(:mkdir, '-p', tmp_path)

        git(:clone, fetch(:repo_url), repo_cache_path)
      end

      # Update repo and submodules to branch
      #
      # @return void
      def update
        git(:remote, :update)
        git(:reset, '--hard', commit_hash)

        # submodules
        if fetch(:with_submodules)
          git(:submodule, :init)
          git(:submodule, :update)
          git(:submodule, :foreach, '--recursive', :git, :submodule, :update, '--init')
        end

        # cleanup
        git(:clean, '-d', '-f') if fetch(:with_clean)

        git(:submodule, :foreach, '--recursive', :git, :clean, '-d', '-f') if fetch(:with_submodules)
      end

      # Create tar archive
      #
      # @return void
      def prepare_release
        package_release_archive

        exclude_files_from_archive if fetch(:git_excludes, []).length.positive?
      end

      # Upload and extract release
      #
      # @return void
      def release
        backend.execute :mkdir, '-p', release_path

        remote_archive_path = File.join(fetch(:deploy_to), File.basename(archive_path))

        backend.upload!(archive_path, remote_archive_path)

        extract_archive_on_remote(remote_archive_path)
      end

      # Set deployed revision
      #
      # @return void
      def fetch_revision
        backend.capture(:git, 'rev-list', '--max-count=1', '--abbrev-commit', commit_hash).strip
      end

      # Cleanup repo cache
      #
      # @return void
      def cleanup
        backend.execute(:rm, '-rf', tmp_path)

        backend.info('Local repo cache was removed')
      end

      # Temporary path for all git-copy operations
      #
      # @return [String]
      def tmp_path
        @tmp_path ||= File.join(Dir.tmpdir, deploy_id)
      end

      # Path to repository cache
      #
      # @return [String]
      def repo_cache_path
        @repo_cache_path ||= fetch(:git_repo_cach_path, File.join(tmp_path, 'repo'))
      end

      # Path to archive
      #
      # @return [String]
      def archive_path
        @archive_path ||= File.join(tmp_path, 'archive.tar.gz')
      end
    end
  end
end
