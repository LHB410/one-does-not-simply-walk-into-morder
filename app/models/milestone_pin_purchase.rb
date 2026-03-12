class MilestonePinPurchase < ApplicationRecord
  belongs_to :user
  belongs_to :milestone

  validates :milestone_id, uniqueness: { scope: :user_id }
end
