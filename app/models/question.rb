class Question < ApplicationRecord
  belongs_to :user
  validates :user_question, presence: true

  after_create :ai_request

  private

  def ai_request
    ChatbotJob.perform_later(self)
  end
end
