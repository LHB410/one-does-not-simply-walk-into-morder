# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Clear existing data
PathUser.destroy_all
Step.destroy_all
User.destroy_all
Milestone.destroy_all
Path.destroy_all

puts "Creating paths..."

# Part 1: Journey to Mordor
part_one = Path.create!(
  name: "Journey to Mordor",
  part_number: 1,
  total_distance_miles: 1350, # Approximate total for Part 1
  active: true
)

# Part 1 Milestones with distances
milestones_part_one = [
  { name: "Shire", distance: 0, cumulative: 0, x: 21.10, y: 27.42 },
  { name: "Rivendell", distance: 458, cumulative: 458, x: 47.73, y: 26.82 },
  { name: "Moria", distance: 200, cumulative: 658, x: 45.96, y: 38.66 },
  { name: "Lothlórien", distance: 112, cumulative: 770, x: 52.66, y: 41.22 },
  { name: "Falls of Rauros", distance: 389, cumulative: 1159, x: 62.52, y: 61.54 },
  { name: "Dead Marshes", distance: 90, cumulative: 1249, x: 66.47, y: 60.55 },
  { name: "Shelob's Lair", distance: 80, cumulative: 1329, x: 73.18, y: 68.44 },
  { name: "Mount Doom", distance: 21, cumulative: 1350, x: 77.71, y: 65.68 }
]

milestones_part_one.each_with_index do |milestone_data, index|
  Milestone.create!(
    path: part_one,
    name: milestone_data[:name],
    distance_from_previous_miles: milestone_data[:distance],
    cumulative_distance_miles: milestone_data[:cumulative],
    sequence_order: index,
    map_position_x: milestone_data[:x],
    map_position_y: milestone_data[:y]
  )
end

# Part 2: Grey Havens
part_two = Path.create!(
  name: "Journey to Grey Havens",
  part_number: 2,
  total_distance_miles: 200, # Shire to Grey Havens
  active: false
)

milestones_part_two = [
  { name: "Shire", distance: 0, cumulative: 0, x: 21.10, y: 27.42 },
  { name: "Grey Havens", distance: 200, cumulative: 200, x: 7.10, y: 24.65 }
]

milestones_part_two.each_with_index do |milestone_data, index|
  Milestone.create!(
    path: part_two,
    name: milestone_data[:name],
    distance_from_previous_miles: milestone_data[:distance],
    cumulative_distance_miles: milestone_data[:cumulative],
    sequence_order: index,
    map_position_x: milestone_data[:x],
    map_position_y: milestone_data[:y]
  )
end

puts "Creating users..."

users_data = [
  { name: "Laura", email: "laura.brooks0@outlook.com", admin: true, color: "#4169E1" },
  { name: "Sonja", email: "sonjaschmidt23@gmail.com", admin: false, color: "#FFD700" },
  { name: "Mellisa", email: "magoodway@gmail.com", admin: false, color: "#32CD32" },
  { name: "Megan", email: "fullmetal.migliushka@gmail.com", admin: false, color: "#FF6347" }
]

users_data.each do |user_data|
  user = User.create!(
    name: user_data[:name],
    email: user_data[:email],
    password: "iCanCarryYou!11",
    password_confirmation: "iCanCarryYou!11",
    admin: user_data[:admin],
    token_color: user_data[:color]
  )

  # Create path association
  PathUser.create!(
    user: user,
    path: part_one,
    current_milestone: part_one.milestones.first,
    progress_percentage: 0.0
  )

  puts "Created user: #{user.name} (#{user.email})"
end

puts "Seed complete!"
puts "Login with any user email and password: iCanCarryYou!11"
puts "Admin user: laura.brooks0@outlook.com"
