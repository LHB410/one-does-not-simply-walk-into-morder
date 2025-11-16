FactoryBot.define do
  factory :path do
    name { "Journey to Mordor" }
    part_number { 1 }
    total_distance_miles { 1000 }
    active { false }

    trait :active do
      active { true }
    end
  end
end
