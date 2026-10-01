# frozen_string_literal: true

module Admin
  class ChargesController < ApplicationController
    include SeasonScoped

    before_action :require_admin
    before_action :set_spot

    def update
      save_charges
      redirect_to back_to_player, notice: t('.saved', name: @player.full_name)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to back_to_player, alert: e.record.errors.full_messages.to_sentence
    end

    private

    def save_charges
      Charge.transaction do
        @season.fees.each do |fee|
          entry = entries[fee.id.to_s]
          apply(fee, entry) if entry
        end
      end
    end

    def back_to_player
      edit_admin_player_path(@player, season: @season)
    end

    def set_spot
      @player = Player.find(params.expect(:player_id))
      @season = current_season
      @spot = RosterSpot.find_by!(season: @season, player: @player)
    end

    def entries
      params.fetch(:charges, {})
    end

    def apply(fee, entry)
      charge = @spot.charges.find_by(fee: fee)
      return remove(charge, fee) unless entry[:charged] == '1'

      charge ||= @spot.charges.new(fee: fee, amount_cents: fee.amount_cents)
      charge.paid_cents = paid_cents(charge, entry)
      charge.save!
    end

    def remove(charge, fee)
      return unless charge
      return charge.destroy! if charge.paid_cents.zero?

      charge.errors.add(:base, t('admin.charges.update.has_payment', fee: fee.name))
      raise ActiveRecord::RecordInvalid, charge
    end

    def paid_cents(charge, entry)
      return charge.amount_cents if entry[:paid_in_full] == '1'

      entry[:paid].blank? ? 0 : Dollars.to_cents(entry[:paid])
    end
  end
end
