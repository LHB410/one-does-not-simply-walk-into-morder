FactoryBot.define do
  factory :path_user do
    association :user
    association :path
    association :current_milestone, factory: :milestone
    progress_percentage { 0.0 }
  end
end
