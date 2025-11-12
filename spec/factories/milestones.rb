FactoryBot.define do
  factory :milestone do
    association :path
    sequence(:name) { |n| "Milestone #{n}" }
    distance_from_previous_miles { 100 }
    cumulative_distance_miles { 100 }
    sequence(:sequence_order)
    map_position_x { 50.0 }
    map_position_y { 50.0 }
  end
end
