# frozen_string_literal: true

module League
  class SnapshotImport
    class MatchNightImport
      attr_reader :season, :canceled_dates, :report

      def initialize(season, canceled_dates, report)
        @season = season
        @canceled_dates = Array(canceled_dates)
        @report = report
      end

      def import(weeks)
        nights = {}
        valid_weeks(weeks).group_by { |week| week['date'] }.each_value do |grouped|
          night = build(grouped)
          report.increment_match_nights
          grouped.each { |week| nights[week['id']] = night }
        end
        nights
      end

      private

      def valid_weeks(weeks)
        weeks.select { |week| valid_week?(week) }
      end

      def valid_week?(week)
        return true if week['date'].present? && week['label'].present?

        report.warn("Week #{week['id'].inspect}: missing date or label, skipped.")
        false
      end

      def build(weeks)
        season.match_nights.create!(scheduling_attributes(weeks).merge(content_attributes(weeks)))
      end

      def scheduling_attributes(weeks)
        {
          played_on: weeks.first['date'],
          playoff: weeks.pluck('label').any? { |label| label.match?(/semi|final/i) },
          canceled: canceled_dates.include?(weeks.first['date'])
        }
      end

      def content_attributes(weeks)
        {
          label: weeks.pluck('label').join(' / ').first(60),
          venue: weeks.filter_map { |week| week['venue'].presence }.first,
          notes: weeks.filter_map { |week| week['time'].presence }.join(' / ').presence
        }
      end
    end
  end
end
