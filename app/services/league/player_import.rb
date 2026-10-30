# frozen_string_literal: true

module League
  class PlayerImport
    Result = Data.define(:read, :added, :existed, :junk)

    MIN_PHONE_DIGITS = 7

    def initialize(text)
      @lines = text.to_s.lines.map(&:strip).compact_blank
      @counts = { added: 0, existed: 0, junk: 0 }
      load_known
    end

    def call
      @lines.each { |line| import_line(line) }
      Result.new(read: @lines.size, **@counts)
    end

    private

    def load_known
      @emails = Player.where.not(email: nil).pluck(:email).to_set
      @phones = Player.where.not(phone: nil).pluck(:phone).filter_map { |phone| phone_key(phone) }.to_set
      @schools = School.all.index_by { |school| school.name.downcase }
    end

    def import_line(line)
      email, name, phone, school = line.split(',', 4).map(&:strip)
      email = email.to_s.downcase
      return @counts[:junk] += 1 unless email.match?(URI::MailTo::EMAIL_REGEXP) && name.present?
      return @counts[:existed] += 1 if duplicate?(email, phone)

      create_player(email, name, phone, school)
    end

    def create_player(email, name, phone, school)
      first_name, last_name = Player.split_name(name)
      player = Player.new(first_name: first_name, last_name: last_name, email: email, phone: phone,
                          school: @schools[school.to_s.downcase])
      return @counts[:junk] += 1 unless player.save

      @emails << email
      @phones << phone_key(phone) if phone_key(phone)
      @counts[:added] += 1
    end

    def duplicate?(email, phone)
      key = phone_key(phone)
      @emails.include?(email) || (key && @phones.include?(key))
    end

    def phone_key(phone)
      digits = phone.to_s.gsub(/\D/, '')
      digits = digits.delete_prefix('1') if digits.size == 11
      digits if digits.size >= MIN_PHONE_DIGITS
    end
  end
end
