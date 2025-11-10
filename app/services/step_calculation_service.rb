class StepCalculationService
  STEPS_PER_MILE = 2112

  def self.miles_to_steps(miles)
    (miles * STEPS_PER_MILE).to_i
  end

  def self.steps_to_miles(steps)
    (steps / STEPS_PER_MILE.to_f).round(2)
  end
end
