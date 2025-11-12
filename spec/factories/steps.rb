FactoryBot.define do
  factory :step do
    association :user, skip_create_step: true
    total_steps { 0 }
    steps_today { 0 }
    steps_until_mordor { 2_112_000 }
    steps_until_next_milestone { 844_800 }
    last_updated_date { nil }
  end
end
