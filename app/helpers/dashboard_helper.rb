# app/helpers/dashboard_helper.rb
module DashboardHelper
  def path_coordinates(path)
    # Generate SVG path from milestone coordinates
    return "" unless path&.milestones&.any?

    points = path.milestones.map do |m|
      "#{m.map_position_x},#{m.map_position_y}"
    end

    # Create a smooth curved path
    "M #{points.join(' L ')}"
  end

  def calculate_token_position(path_user, path)
  return { x: 10, y: 80 } unless path_user&.current_milestone

  current_milestone = path_user.current_milestone
  next_milestone = path.next_milestone_after(current_milestone)

  if next_milestone && path_user.progress_percentage < 100
    # Compute segment progress using steps to avoid rounding snaps
    current_steps = (current_milestone.cumulative_distance_miles * Step::STEPS_PER_MILE)
    next_steps    = (next_milestone.cumulative_distance_miles * Step::STEPS_PER_MILE)

    steps_from_current = [ path_user.user.step.total_steps - current_steps, 0 ].max
    steps_to_next      = [ next_steps - current_steps, 0 ].max

    progress_fraction =
      steps_to_next.positive? ? (steps_from_current / steps_to_next.to_f) : 0.0
    progress_fraction = progress_fraction.clamp(0.0, 1.0)

    puts "[DashboardHelper#calculate_token_position] user_id=#{path_user.user_id} current=#{current_milestone.name}(cum=#{current_milestone.cumulative_distance_miles}) next=#{next_milestone.name}(cum=#{next_milestone.cumulative_distance_miles}) total_steps=#{path_user.user.step.total_steps} steps_from_current=#{steps_from_current} steps_to_next=#{steps_to_next} fraction=#{progress_fraction}"

    # Interpolate along the segment without mutating DB state here
    x = current_milestone.map_position_x +
        (next_milestone.map_position_x - current_milestone.map_position_x) * progress_fraction
    y = current_milestone.map_position_y +
        (next_milestone.map_position_y - current_milestone.map_position_y) * progress_fraction

    { x: x, y: y }
  else
    { x: current_milestone.map_position_x, y: current_milestone.map_position_y }
  end
  end
end
