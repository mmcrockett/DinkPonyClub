# frozen_string_literal: true

class SchoolIconsController < ApplicationController
  def show
    school = School.find(params.expect(:id))
    return head :not_found unless school.icon.attached?

    response.headers['X-Content-Type-Options'] = 'nosniff'
    send_data school.icon.download, type: school.icon.content_type, disposition: 'inline'
  end
end
