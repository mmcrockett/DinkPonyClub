# frozen_string_literal: true

module League
  class SnapshotImport
    class FeeImport
      LEAGUE_FEE_NAME = 'League fee'
      # The clubhouse export flags orders but not prices; these are the clubhouse UI's fixed prices.
      ITEMS = { 'shirt' => ['Shirt', 3000], 'hat' => ['Hat', 3500] }.freeze

      attr_reader :season, :players, :report

      def initialize(season, players, report)
        @season = season
        @players = players
        @report = report
        @item_fees = {}
      end

      def import(league_fee_dollars, people)
        @league_fee = create_league_fee(league_fee_dollars)
        people.each { |person| import_person(person) }
      end

      private

      def create_league_fee(dollars)
        amount_cents = Dollars.to_cents(dollars)
        return unless amount_cents&.positive?

        fee = season.fees.create!(name: LEAGUE_FEE_NAME, amount_cents: amount_cents, applies_to_all: true)
        report.increment_fees
        report.add(:charges, fee.charges.count)
        fee
      end

      def import_person(person)
        spot = season.roster_spots.find_by(player: players[person['name']])
        return warn_unrostered(person) unless spot

        mark_league_fee_paid(spot) if person['paid']
        ITEMS.each_key { |key| charge_item(spot, key, paid: person["#{key}Paid"]) if person[key] }
      end

      def mark_league_fee_paid(spot)
        return unless @league_fee

        spot.charges.find_by!(fee: @league_fee).update!(paid_cents: @league_fee.amount_cents)
        report.increment_charges_paid
      end

      def charge_item(spot, key, paid:)
        fee = item_fee(key)
        spot.charges.create!(fee: fee, amount_cents: fee.amount_cents, paid_cents: paid ? fee.amount_cents : 0)
        report.increment_charges
        report.increment_charges_paid if paid
      end

      def item_fee(key)
        @item_fees[key] ||= begin
          name, amount_cents = ITEMS.fetch(key)
          report.increment_fees
          season.fees.create!(name: name, amount_cents: amount_cents, applies_to_all: false)
        end
      end

      def warn_unrostered(person)
        flags = (%w[paid] + ITEMS.keys).select { |key| person[key] }
        return if flags.empty?

        report.warn("#{person['name']} has no roster spot, so their fee data (#{flags.join(', ')}) was not imported.")
      end
    end
  end
end
