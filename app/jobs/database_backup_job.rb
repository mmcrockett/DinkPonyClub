# frozen_string_literal: true

class DatabaseBackupJob < ApplicationJob
  queue_as :default

  def perform
    unless backup_configured?
      Rails.logger.info('DatabaseBackupJob: no mysql_backup config, skipping')
      return
    end

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    counts = League::DatabaseCopy.new(source: :primary, target: :mysql_backup).call
    log_result(counts, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
  end

  private

  def backup_configured?
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'mysql_backup').present?
  end

  def log_result(counts, seconds)
    summary = counts.map { |table, count| "#{table}=#{count}" }.join(' ')
    Rails.logger.info("DatabaseBackupJob: copied in #{seconds.round(2)}s #{summary}")
  end
end
