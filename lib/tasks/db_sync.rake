# frozen_string_literal: true

namespace :db do
  namespace :sync do
    desc 'Replace every table in database TO with the rows from database FROM (names from config/database.yml)'
    task copy: :environment do
      from = ENV.fetch('FROM') { abort 'Set FROM=<config name>' }
      to = ENV.fetch('TO') { abort 'Set TO=<config name>' }
      counts = League::DatabaseCopy.new(source: from, target: to).call
      counts.each { |table, count| puts "#{table}: #{count}" }
    rescue League::DatabaseCopy::Error => e
      abort(e.message)
    end
  end
end
