# frozen_string_literal: true

namespace :league do
  desc 'Import a clubhouse Season JSON export (FORCE=1 to replace an existing season)'
  task :import_snapshot, %i[path] => :environment do |_task, args|
    data = JSON.parse(File.read(args.fetch(:path)))
    report = League::SnapshotImport.new(data, force: ENV['FORCE'] == '1').call
    puts report
  rescue Errno::ENOENT, JSON::ParserError, League::SnapshotImport::Error, ActiveRecord::RecordInvalid => e
    abort(e.message)
  end
end
