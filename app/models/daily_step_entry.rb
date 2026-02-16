class DailyStepEntry < ApplicationRecord
  belongs_to :user
  belongs_to :path

  validates :date, presence: true
  validates :steps, numericality: { greater_than_or_equal_to: 0 }

  scope :for_user_on_path, ->(user, path) {
    where(user: user, path: path)
  }

  def self.record!(user:, path:, date:, steps:)
    return unless user && path && steps.to_i.positive?

    entry = find_or_initialize_by(user: user, path: path, date: date)
    entry.steps = entry.steps.to_i + steps.to_i
    entry.save!
  end

  def self.daily_totals_for(user:, path:, page:, per_page:)
    page = page.to_i
    page = 1 if page < 1

    relation = for_user_on_path(user, path)

    min_date = relation.minimum(:date)
    max_date = relation.maximum(:date)
    return relation.none unless min_date && max_date

    last_date = [ max_date, Date.current ].max

    # Calculate the page window arithmetically instead of building a full date array.
    # Dates are in descending order, so page 1 starts from last_date.
    offset = (page - 1) * per_page
    page_end_date = last_date - offset
    page_start_date = [ last_date - offset - per_page + 1, min_date ].max

    return [] if page_end_date < min_date

    # Only query entries within the current page's date range
    totals_by_date = relation
      .where(date: page_start_date..page_end_date)
      .group(:date)
      .select("date, SUM(steps) AS total_steps")
      .index_by(&:date)

    # Build the page's date list (descending) and fill gaps with zero-step entries
    (page_start_date..page_end_date).to_a.reverse.map do |date|
      totals_by_date[date] || new(date: date, steps: 0)
    end
  end

  def self.total_days_for(user:, path:)
    relation = for_user_on_path(user, path)
    min_date = relation.minimum(:date)
    max_date = relation.maximum(:date)
    return 0 unless min_date && max_date

    # Count every calendar day in the range, not just days with entries
    last_date = [ max_date, Date.current ].max
    (last_date - min_date).to_i + 1
  end
end
