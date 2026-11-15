require 'test_helper'
require 'open3'
require 'tmpdir'

class DockerLauncherTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir
    @log = File.join(@directory, 'docker.log')
    docker = File.join(@directory, 'docker')
    File.write(docker, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$@" >> "$DOCKER_LOG"
      if [ "$1" = build ]; then
        [ "${DOCKER_BUILD_STATUS:-0}" -eq 0 ] || exit "$DOCKER_BUILD_STATUS"
        echo fake-image
      else
        exit "${DOCKER_RUN_STATUS:-0}"
      fi
    SH
    File.chmod(0o755, docker)
  end

  teardown { FileUtils.remove_entry(@directory) }

  test 'test launcher forwards selectors without requiring a server' do
    _, _, status = launch('test-docker', 'test/models/game_test.rb:12', '--name', 'a test')

    assert_predicate status, :success?
    assert_includes arguments, ['fake-image', 'bin/rails', 'test', 'test/models/game_test.rb:12', '--name', 'a test']
    assert_includes arguments, ['--env', 'RAILS_ENV=test']
  end

  test 'rubocop launcher forwards options and container failures' do
    _, _, status = launch('rubocop-docker', '-a', 'a file.rb', 'DOCKER_RUN_STATUS' => '42')

    assert_equal 42, status.exitstatus
    assert_includes arguments, ['fake-image', 'bin/rubocop', '-a', 'a file.rb']
  end

  test 'development launcher publishes the requested port' do
    _, _, status = launch('dev-docker')

    assert_predicate status, :success?
    assert_includes arguments, ['--publish', '127.0.0.1:3312:3312']
    assert_includes arguments, ['--env', 'BINDING=0.0.0.0']
  end

  test 'build failures stop before running a container' do
    _, _, status = launch('test-docker', 'DOCKER_BUILD_STATUS' => '37')

    assert_equal 37, status.exitstatus
    assert_not_includes File.readlines(@log, chomp: true), 'run'
  end

  private

  def launch(command, *args)
    extra_env = args.last.is_a?(Hash) ? args.pop : {}
    env = { 'PATH' => "#{@directory}:#{ENV.fetch('PATH')}", 'DOCKER_LOG' => @log }.merge(extra_env)
    Open3.capture3(env, Rails.root.join('bin', command).to_s, *args)
  end

  def arguments
    File.readlines(@log, chomp: true).each_cons(6).to_a +
      File.readlines(@log, chomp: true).each_cons(4).to_a +
      File.readlines(@log, chomp: true).each_cons(2).to_a
  end
end
