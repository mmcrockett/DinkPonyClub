# frozen_string_literal: true

namespace :admin do
  desc 'Grant admin to the player with the given email'
  task :grant, %i[email] => :environment do |_task, args|
    player = Player.locate_by_email!(args[:email])
    player.update!(admin: true)
    puts "Granted admin to #{player.full_name} <#{player.email}>."
  rescue ActiveRecord::RecordNotFound => e
    abort(e.message)
  end

  desc 'Revoke admin from the player with the given email'
  task :revoke, %i[email] => :environment do |_task, args|
    player = Player.locate_by_email!(args[:email])
    player.update!(admin: false)
    puts "Revoked admin from #{player.full_name} <#{player.email}>."
  rescue ActiveRecord::RecordNotFound => e
    abort(e.message)
  end

  desc 'List admins'
  task list: :environment do
    admins = Player.admins.by_name

    if admins.none?
      puts 'No admins.'
    else
      admins.each { |player| puts "#{player.full_name} <#{player.email}>" }
    end
  end
end
