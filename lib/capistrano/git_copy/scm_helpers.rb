require 'tmpdir'

module Capistrano
  module GitCopy
    # Helper methods for capistrano SCM plugin
    module SCMHelpers
      private

      def deploy_id
        [
          fetch(:application),
          fetch(:stage),
          Digest::MD5.hexdigest(fetch(:repo_url))[0..7],
          Digest::MD5.hexdigest(Dir.getwd)[0..7]
        ].compact.join('_').gsub(/[^\w]/, '')
      end

      def commit_hash
        return @commit_hash if @commit_hash

        branch = fetch(:branch, 'master').to_s.strip

        @commit_hash = if backend.test(:git, 'rev-parse', "origin/#{branch}", '>/dev/null 2>/dev/null')
                         backend.capture(:git, 'rev-parse', "origin/#{branch}").strip
                       else
                         backend.capture(:git, 'rev-parse', branch).strip
                       end
      end

      def git_archive_all_bin
        File.expand_path('../../../vendor/git-archive-all/git_archive_all.py', __dir__)
      end

      def git(*args)
        backend.execute(:git, *args)
      end

      def check_repo_cache_path
        backend.within(repo_cache_path) do
          if backend.test(:git, :status, '>/dev/null 2>/dev/null')
            true
          else
            backend.execute(:rm, '-rf', repo_cache_path)

            false
          end
        end
      end

      def package_release_archive
        if fetch(:upload_path) != '.'
          backend.execute(:tar, '-czf', archive_path, '-C', fetch(:upload_path), '.')
        elsif fetch(:with_submodules)
          backend.execute(git_archive_all_bin, "--prefix=''", archive_path)
        else
          git(:archive, '--format=tar', 'HEAD', '|', 'gzip', "> #{archive_path}")
        end
      end

      def exclude_files_from_archive
        archive_dir = File.join(tmp_path, 'archive')

        backend.execute(:rm, '-rf', archive_dir)
        backend.execute(:mkdir, '-p', archive_dir)
        backend.execute(:tar, '-xzf', archive_path, '-C', archive_dir)

        remove_file_from_archive_dir(archive_dir)

        backend.execute(:tar, '-czf', archive_path, '-C', archive_dir, '.')
      end

      def remove_file_from_archive_dir(archive_dir)
        fetch(:git_excludes, []).each do |f|
          file_path = File.join(archive_dir, f.gsub(%r{\A/}, ''))

          unless File.exist?(file_path)
            backend.warn("#{f} does not exists!")

            next
          end

          FileUtils.rm_rf(file_path)
        end
      end

      def extract_archive_on_remote(remote_archive_path)
        backend.execute(:mkdir, '-p', release_path)
        backend.execute(:tar, '-f', remote_archive_path, '-x', '-C', release_path)
        backend.execute(:rm, '-f', remote_archive_path)
      end
    end
  end
end
