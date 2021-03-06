require 'FileHelpers'
require 'git-process/git_process'

module GitRepoHelper

  def gitprocess
    opts = {}
    opts[:quiet] = true if log_level == Logger::ERROR
    opts[:verbose] = true if log_level == Logger::DEBUG
    @gitprocess ||= create_process(tmpdir, opts)
  end


  def tmpdir
    @tmpdir ||= Dir.mktmpdir
  end


  def commit_count
    gitprocess.log_count
  end


  def log_level
    Logger::ERROR
  end


  def logger
    gitprocess.logger
  end


  def create_files(file_names)
    Dir.chdir(gitprocess.workdir) do |dir|
      file_names.each do |fn|
        gitprocess.logger.debug { "Creating #{dir}/#{fn}" }
        FileUtils.touch fn
      end
    end
    gitprocess.add(file_names)
  end


  def change_file(filename, contents, lib = gitprocess)
    Dir.chdir(lib.workdir) do
      File.open(filename, 'w') { |f| f.puts contents }
    end
  end


  def change_file_and_add(filename, contents, lib = gitprocess)
    change_file(filename, contents, lib)
    lib.add(filename)
  end


  def change_file_and_commit(filename, contents, lib = gitprocess)
    change_file_and_add(filename, contents, lib)
    lib.commit("#{filename} - #{contents}")
  end


  def create_process(dir, opts)
    GitProc::Process.new(dir, opts)
  end


  def clone(branch='master', remote_name = 'origin', &block)
    td = Dir.mktmpdir

    logger.debug { "Cloning '#{tmpdir}' to '#{td}'" }

    opts = {}
    opts[:quiet] = true if log_level == Logger::ERROR
    opts[:verbose] = true if log_level == Logger::DEBUG
    gl = create_process(td, opts)
    gl.add_remote(remote_name, "file://#{tmpdir}")
    gl.fetch(remote_name)

    if branch == 'master'
      gl.reset("#{remote_name}/#{branch}", :hard => true)
    else
      gl.checkout(branch, :new_branch => "#{remote_name}/#{branch}")
    end

    if block_given?
      begin
        block.arity < 1 ? gl.instance_eval(&block) : block.call(gl)
      rescue => exp
        rm_rf(gl.workdir)
        raise exp
      end
      nil
    else
      gl
    end
  end

end
