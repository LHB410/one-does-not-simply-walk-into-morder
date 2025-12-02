FactoryBot.define do
  factory :daily_step_entry do
    association :user
    association :path
    date { Date.current }
    steps { 1000 }
  end
end
