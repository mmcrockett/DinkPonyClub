# frozen_string_literal: true

module League
  class SnapshotImport
    class PlayerResolver
      attr_reader :report

      def initialize(report)
        @report = report
      end

      def resolve(person)
        player = find(person)
        if player
          report.increment_players_matched
        else
          player = create(person)
        end
        fill_contact_details(player, person)
        player
      end

      private

      def find(person)
        email = person['email'].to_s.strip.downcase.presence
        (email && Player.find_by(email: email)) || find_by_name(person)
      end

      def find_by_name(person)
        first_name, last_name = split_name(person['name'])
        Player.find_by(first_name: first_name, last_name: last_name)
      end

      def create(person)
        first_name, last_name = split_name(person['name'])
        warn_missing_space(person, last_name)
        email = person['email'].to_s.strip.downcase.presence
        player = Player.create!(first_name: first_name, last_name: last_name, email: email, status: 'active')
        report.increment_players_created
        player
      end

      def warn_missing_space(person, last_name)
        return if person['name'].to_s.strip.include?(' ')

        report.warn("#{person['name']} has no space in its name; using \"#{last_name}\" as the last name.")
      end

      def split_name(name)
        parts = name.to_s.strip.split
        return [name.to_s.strip, '-'] if parts.size < 2

        [parts[0..-2].join(' '), parts.last]
      end

      def fill_contact_details(player, person)
        backfill_email(player, person)
        player.phone = person['phone'] if player.phone.blank? && person['phone'].present?
        player.contact_email = person['contactEmail'] if player.contact_email.blank? && person['contactEmail'].present?
        player.save! if player.changed?
      end

      def backfill_email(player, person)
        email = person['email'].to_s.strip.downcase.presence
        return if email.nil? || player.email.present?

        player.email = email
        report.increment_emails_backfilled
      end
    end
  end
end
