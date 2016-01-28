require 'tmpdir'
require 'digest/md5'

module Capistrano
  module GitCopy
    # Utility stuff to avoid cluttering of deploy.cap
    class Utility
      attr_reader :with_submodules
      attr_reader :git_excludes

      def initialize(context)
        @context         = context
        @with_submodules = fetch(:with_submodules, true)
        @repo_tree = fetch(:repo_tree, false)
        @with_submodules = @repo_tree? false : @with_submodules # If repo_tree is specified, set with_submodules to false
        @git_excludes    = fetch(:git_excludes, [])
      end

      # Check if repo cache exists and is valid
      #
      # @return [Boolean] indicates if repo cache exists
      def test
        if test!("[ -d #{repo_path} ]")
          @context.within(repo_path) do
            if test!(:git, :status, '>/dev/null 2>/dev/null')
              true
            else
              execute(:rm, '-rf', repo_path)
              false
            end
          end
        else
          false
        end
      end

      # Check if repo is accessible
      #
      # @return void
      def check
        git(:'ls-remote --heads', repo_url)
      end

      # Clone repo to cache
      #
      # @return void
      def clone
        execute(:mkdir, '-p', tmp_path)

        git(:clone, fetch(:repo_url), repo_path)
      end

      # Update repo and submodules to branch
      #
      # @return void
      def update
        git(:remote, :update)
        git(:reset, '--hard', commit_hash)

        # submodules
        if with_submodules
          git(:submodule, :init)
          git(:submodule, :update)
          git(:submodule, :foreach, '--recursive', :git, :submodule, :update, '--init')
        end

        # cleanup
        git(:clean, '-d', '-f')
        if with_submodules
          git(:submodule, :foreach, '--recursive', :git, :clean, '-d', '-f')
        end
      end

      # Create tar archive
      #
      # @return void
      def prepare_release
        target = @repo_tree? "HEAD:#{@repo_tree}" : "HEAD"
        if with_submodules
          execute(git_archive_all_bin, "--prefix=''", archive_path)
        else
          git(:archive, '--format=tar', target, '|', 'gzip', "> #{archive_path}")
        end

        if git_excludes.count > 0
          archive_dir = File.join(tmp_path, 'archive')

          execute :rm, '-rf', archive_dir
          execute :mkdir, '-p', archive_dir
          execute :tar, '-xzf', archive_path, '-C', archive_dir

          git_excludes.each do |f|
            file_path = File.join(archive_dir, f.gsub(/\A\//, ''))

            unless File.exists?(file_path)
              warn("#{f} does not exists!")
              next
            end

            FileUtils.rm_rf(file_path)
          end

          execute :tar, '-czf', archive_path, '-C', archive_dir, '.'
        end
      end

      # Upload and extract release
      #
      # @return void
      def release
        remote_archive_path = File.join(fetch(:deploy_to), File.basename(archive_path))

        upload!(archive_path, remote_archive_path)

        execute(:mkdir, '-p', release_path)
        execute(:tar, '-f', remote_archive_path, '-x', '-C', release_path)
        execute(:rm, '-f', remote_archive_path)
      end

      # Set deployed revision
      #
      # @return void
      def fetch_revision
        capture(:git, 'rev-list', '--max-count=1', '--abbrev-commit', commit_hash).strip
      end

      # Cleanup repo cache
      #
      # @return void
      def cleanup
        execute(:rm, '-rf', tmp_path)

        info('Local repo cache was removed')
      end

      # Temporary path for all git-copy operations
      #
      # @return [String]
      def tmp_path
        @_tmp_path ||= File.join(Dir.tmpdir, deploy_id)
      end

      # Path to repo cache
      #
      # @return [String]
      def repo_path
        @_repo_path ||= File.join(tmp_path, 'repo')
      end

      # Path to archive
      #
      # @return [String]
      def archive_path
        @_archive_path ||= File.join(tmp_path, 'archive.tar.gz')
      end

      private

      def fetch(*args)
        @context.fetch(*args)
      end

      def test!(*args)
        @context.test(*args)
      end

      def execute(*args)
        @context.execute(*args)
      end

      def capture(*args)
        @context.capture(*args)
      end

      def upload!(*args)
        @context.upload!(*args)
      end

      def info(*args)
        @context.info(*args)
      end

      def warn(*args)
        @context.warn(*args)
      end

      def git(*args)
        execute(:git, *args)
      end

      def git_archive_all_bin
        File.expand_path('../../../../vendor/git-archive-all/git_archive_all.py', __FILE__)
      end

      def deploy_id
        [
          fetch(:application),
          fetch(:stage),
          Digest::MD5.hexdigest(fetch(:repo_url))[0..7],
          Digest::MD5.hexdigest(Dir.getwd)[0..7]
        ].compact.join('_').gsub(/[^\w]/, '')
      end

      def commit_hash
        return @_commit_hash if @_commit_hash

        branch = fetch(:branch, 'master').to_s.strip

        if test!(:git, 'rev-parse', "origin/#{branch}", '>/dev/null 2>/dev/null')
          @_commit_hash = capture(:git, 'rev-parse', "origin/#{branch}").strip
        else
          @_commit_hash = capture(:git, 'rev-parse', branch).strip
        end
      end
    end
  end
end
