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
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("Failed to record DailyStepEntry: #{e.class} - #{e.message}")
  end

  def self.daily_totals_for(user:, path:, page:, per_page:)
    page = page.to_i
    page = 1 if page < 1

    relation = for_user_on_path(user, path)

    # If there are no entries yet, just return an empty relation
    min_date = relation.minimum(:date)
    max_date = relation.maximum(:date)
    return relation.none unless min_date && max_date

    # Always show up to today, even if there haven't been entries for a while
    last_date = [ max_date, Date.current ].max

    # Build a continuous list of dates from the first entry to the last (or today),
    # then paginate over that list of days
    all_dates_desc = (min_date..last_date).to_a.sort.reverse
    offset = (page - 1) * per_page
    paginated_dates = all_dates_desc.slice(offset, per_page) || []

    # Preload actual totals for days that have data
    totals_by_date = relation
      .group(:date)
      .order(date: :desc)
      .select("date, SUM(steps) AS total_steps")
      .index_by(&:date)

    # For days without an entry, synthesize a zero-steps entry so the view can render it
    paginated_dates.map do |date|
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
