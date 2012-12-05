require 'git-process/pull_request'
require 'github_test_helper'
require 'pull_request_helper'
require 'GitRepoHelper'


describe GitProc::PullRequest do
  include GitRepoHelper
  include GitHubTestHelper

  before(:each) do
    create_files(%w(.gitignore))
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  def log_level
    Logger::ERROR
  end


  describe "with no parameters" do
    def create_process(dir, opts)
      GitProc::PullRequest.new(dir, opts)
    end


    it "should push the branch and create a default pull request" do
      pr_client = double('pr_client')

      gitprocess.config('gitProcess.integrationBranch', 'develop')
      gitprocess.add_remote('origin', 'git@github.com:jdigger/git-process.git')

      gitprocess.stub(:create_pull_request_client).with('origin', 'jdigger/git-process').and_return(pr_client)
      gitprocess.should_receive(:push)
      pr_client.should_receive(:create).with('develop', 'master', 'master', '')

      gitprocess.runner
    end


    it "should fail if the base and head branch are the same" do
      gitprocess.add_remote('origin', 'git@github.com:jdigger/git-process.git')

      expect {
        gitprocess.runner
      }.to raise_error GitProc::PullRequestError
    end

  end


  describe "checkout pull request" do
    include PullRequestHelper

    alias :lib :gitprocess


    before(:each) do
      gitprocess.config('gitProcess.github.authToken', 'sdfsfsdf')
      gitprocess.config('github.user', 'jdigger')
    end


    describe "with PR #" do

      def pull_request
        @pr ||= create_pull_request({})
      end


      def create_process(dir, opts)
        GitProc::PullRequest.new(dir, opts.merge({:prNumber => pull_request[:number]}))
      end


      it "should checkout the branch for the pull request" do
        add_remote(:head)
        stub_fetch(:head)

        stub_get_pull_request(pull_request)

        expect_checkout_pr_head()
        expect_upstream_set()

        gitprocess.runner
      end

    end


    describe "with repo name and PR #" do

      def pull_request
        @pr ||= create_pull_request(:base_remote => 'sourcerepo', :base_repo => 'source_repo')
      end


      def create_process(dir, opts)
        GitProc::PullRequest.new(dir, opts.merge({:prNumber => pull_request[:number],
                                                  :server => pull_request[:head][:remote]}))
      end


      it "should checkout the branch for the pull request" do
        add_remote(:head)
        add_remote(:base)
        stub_fetch(:head)
        stub_fetch(:base)

        stub_get_pull_request(pull_request)

        expect_checkout_pr_head()
        expect_upstream_set()

        gitprocess.runner
      end

    end

  end

end
