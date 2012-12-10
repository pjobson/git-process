# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'git-process/git_process'
require 'git-process/pull_request'
require 'git-process/git_rebase_error'
require 'git-process/git_process_error'
require 'git-process/parked_changes_error'
require 'git-process/uncommitted_changes_error'
require 'git-process/github_pull_request'


module GitProc

  class RebaseToMaster < Process

    def initialize(dir, opts)
      @keep = opts[:keep]
      @interactive = opts[:interactive]
      @base_branch = opts[:base_branch]
      @head_branch = opts[:head_branch]
      @_repo_name = opts[:repo_name]
      @_remote_name = opts[:server]
      @pr_number = opts[:prNumber]
      @gitproc_pullrequest = GitProc::PullRequest.new(dir, opts)
      super
    end


    def verify_preconditions
      super

      raise UncommittedChangesError.new unless status.clean?
      raise ParkedChangesError.new(self) if is_parked?
    end


    def runner
      if @pr_number
        to_master_pull_request
      else
        to_master_branch
      end
    end


    def to_master_pull_request
      checkout_pull_request
      to_master_branch
    end


    def checkout_pull_request
      #@gitproc_pullrequest.checkout_pull_request
    end


    def to_master_branch
      if has_a_remote?
        fetch(server_name)
        proc_rebase(integration_branch)
        proc_rebase(integration_branch, :interactive => true) if @interactive
        push(server_name, branches.current, master_branch)

        unless @keep
          close_pull_request
          remove_feature_branch
        end
      else
        proc_rebase(integration_branch)
      end
    end


    alias :lib_repo_name :repo_name
    alias :lib_remote_name :remote_name


    def repo_name
      @_repo_name ||= lib_repo_name
    end


    def remote_name
      @_remote_name ||= lib_remote_name
    end


    def remove_feature_branch
      mybranches = branches

      remote_master = mybranches[remote_master_branch]
      current_branch = mybranches.current
      logger.debug { "Removing feature branch (#{current_branch})" }

      unless remote_master.contains_all_of(current_branch.name)
        raise GitProcessError.new("Branch '#{current_branch.name}' has not been merged into '#{remote_master_branch}'")
      end

      parking_branch = mybranches['_parking_']
      if parking_branch
        if parking_branch.is_ahead_of(remote_master.name) and
            !current_branch.contains_all_of(parking_branch.name)

          parking_branch.rename('_parking_OLD_')

          logger.warn { bad_parking_branch_msg }
        else
          parking_branch.delete!
        end
      end
      remote_master.checkout_to_new('_parking_', :no_track => true)

      current_branch.delete!(true)
      if mybranches["#{server_name}/#{current_branch.name}"]
        push(server_name, nil, nil, :delete => current_branch.name)
      end
    end


    def close_pull_request
      pr = GitHub::PullRequest.new(self, remote_name, repo_name)

      # Assume that if we haven't done something that would create the
      # GitHub auth token, then this likely isn't a GitHub-based repo.
      # (Or at least the user isn't using pull requests)
      if pr.get_config_auth_token
        begin
          mybranches = branches()
          pull = pr.find_pull_request(master_branch, mybranches.current.name)
          if pull
            pr.close(pull[:number])
          else
            logger.debug { "There is no pull request for #{mybranches.current.name} against #{master_branch}" }
          end
        rescue GitHubService::NoRemoteRepository => exp
          logger.debug exp.to_s
        end
      else
        logger.debug "There is no GitHub auth token defined, so not trying to close a pull request."
      end
    end


    private


    def bad_parking_branch_msg
      hl = HighLine.new
      hl.color("\n***********************************************************************************************\n\n"+
                   "There is an old '_parking_' branch with unacounted changes in it.\n"+
                   "It has been renamed to '_parking_OLD_'.\n"+
                   "Please rename the branch to what the changes are about (`git branch -m _parking_OLD_ my_fb_name`),\n"+
                   " or remove it altogher (`git branch -D _parking_OLD_`).\n\n"+
                   "***********************************************************************************************\n", :red, :bold)
    end

  end

end
