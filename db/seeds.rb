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

# Single continuous journey: Shire to Grey Havens
journey = Path.create!(
  name: "Journey to Mordor and Back",
  part_number: 1,
  total_distance_miles: 3659,
  active: true
)

# All milestones with cumulative distances from Shire
milestones = [
  # Journey to Mordor
  { name: "Shire", distance: 0, cumulative: 0, x: 21.10, y: 27.42 },
  { name: "Rivendell", distance: 458, cumulative: 458, x: 47.73, y: 26.82 },
  { name: "Moria", distance: 175, cumulative: 633, x: 45.96, y: 38.66 },
  { name: "Lothlórien", distance: 122, cumulative: 755, x: 52.66, y: 41.22 },
  { name: "Falls of Rauros", distance: 389, cumulative: 1144, x: 62.52, y: 61.54 },
  { name: "Dead Marshes", distance: 102, cumulative: 1246, x: 66.47, y: 60.55 },
  { name: "Shelob's Lair", distance: 189, cumulative: 1435, x: 73.18, y: 68.44 },
  { name: "Mount Doom", distance: 179, cumulative: 1614, x: 77.71, y: 65.68 },
  # Return journey
  { name: "Minas Tirith", distance: 160, cumulative: 1774, x: 68.49, y: 70.49 },
  { name: "Isengard", distance: 535, cumulative: 2309, x: 41.97, y: 53.92 },
  { name: "Hobbiton", distance: 1090, cumulative: 3399, x: 17.56, y: 27.81 },
  { name: "Grey Havens", distance: 260, cumulative: 3659, x: 6.42, y: 26.795 }
]

milestones.each_with_index do |milestone_data, index|
  Milestone.create!(
    path: journey,
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
    path: journey,
    current_milestone: journey.milestones.first,
    progress_percentage: 0.0
  )

  puts "Created user: #{user.name} (#{user.email})"
end

puts "Seed complete!"
puts "Login with any user email and password: iCanCarryYou!11"
puts "Admin user: laura.brooks0@outlook.com"
