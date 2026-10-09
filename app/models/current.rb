class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user

  def user
    super || session&.user
  end
end
