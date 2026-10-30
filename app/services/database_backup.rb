# frozen_string_literal: true

module DatabaseBackup
  CACHE_KEY = 'database_backup/last_success'
  OVERDUE_AFTER = 3.hours

  def self.configured?
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'mysql_backup').present?
  end

  def self.record_success
    Rails.cache.write(CACHE_KEY, Time.current)
  end

  def self.overdue?
    last = Rails.cache.read(CACHE_KEY)
    last.nil? || last < OVERDUE_AFTER.ago
  end

  def self.warn?
    configured? && overdue?
  end
end
