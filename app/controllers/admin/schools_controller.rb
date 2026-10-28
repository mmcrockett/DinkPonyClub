# frozen_string_literal: true

module Admin
  class SchoolsController < ApplicationController
    before_action :require_admin
    before_action :set_school, only: %i[update destroy]

    def index
      @schools = schools
      @school = School.new
    end

    def create
      @school = School.new(school_params)

      if @school.save
        redirect_to admin_schools_path, notice: t('.created', name: @school.name)
      else
        @schools = schools
        render :index, status: :unprocessable_content
      end
    end

    def update
      if @school.update(school_params)
        redirect_to admin_schools_path, notice: t('.updated', name: @school.name)
      else
        redirect_to admin_schools_path, alert: @school.errors.full_messages.to_sentence
      end
    end

    def destroy
      @school.destroy!
      redirect_to admin_schools_path, notice: t('.destroyed', name: @school.name)
    end

    private

    def schools
      School.by_name.includes(:players, icon_attachment: :blob)
    end

    def set_school
      @school = School.find(params.expect(:id))
    end

    def school_params
      params.expect(school: %i[name icon])
    end
  end
end
