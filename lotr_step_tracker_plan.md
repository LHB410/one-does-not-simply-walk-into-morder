# LOTR Step Tracker - Development Plan

## Project Overview
A Lord of the Rings themed step tracking app where 4 friends track their journey from the Shire to Mordor (and eventually Grey Havens) by converting real-world steps into miles along Middle-earth's path.

## Tech Stack
- **Backend**: Rails 8, Ruby 3.4.4, PostgreSQL
- **Frontend**: Rails views with Hotwire/Turbo
- **Hosting**: Heroku
- **External Integration**: Google Sheets API

---

## Database Schema

### Users Table
```ruby
create_table :users do |t|
  t.string :name, null: false
  t.string :email, null: false, index: { unique: true }
  t.string :password_digest, null: false
  t.boolean :admin, default: false
  t.string :token_color # for map marker color
  t.timestamps
end
```

### Steps Table
```ruby
create_table :steps do |t|
  t.references :user, null: false, foreign_key: true, index: { unique: true }
  t.integer :total_steps, default: 0, null: false
  t.integer :steps_today, default: 0, null: false
  t.integer :steps_until_mordor, null: false
  t.integer :steps_until_next_milestone, null: false
  t.date :last_updated_date
  t.timestamps
end
```

### Paths Table
```ruby
create_table :paths do |t|
  t.string :name, null: false # "Part 1: Journey to Mordor", "Part 2: Grey Havens"
  t.integer :part_number, null: false # 1 or 2
  t.integer :total_distance_miles, null: false
  t.boolean :active, default: false
  t.timestamps
end
```

### Milestones Table
```ruby
create_table :milestones do |t|
  t.references :path, null: false, foreign_key: true
  t.string :name, null: false # "Shire", "Rivendell", etc.
  t.integer :distance_from_previous_miles, null: false
  t.integer :cumulative_distance_miles, null: false
  t.integer :sequence_order, null: false
  t.decimal :map_position_x # for visual placement on map
  t.decimal :map_position_y
  t.timestamps
end

add_index :milestones, [:path_id, :sequence_order], unique: true
```

### PathUsers Join Table
```ruby
create_table :path_users do |t|
  t.references :path, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.integer :current_milestone_id
  t.decimal :progress_percentage, default: 0.0
  t.timestamps
end

add_index :path_users, [:path_id, :user_id], unique: true
```

---

## Models

### User Model
```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  has_one :step, dependent: :destroy
  has_many :path_users, dependent: :destroy
  has_many :paths, through: :path_users

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :token_color, presence: true

  after_create :create_associated_step

  scope :non_admin, -> { where(admin: false) }
  scope :admin_users, -> { where(admin: true) }

  def total_miles
    (step.total_steps * 0.0004735).round(2) # ~2,112 steps per mile average
  end

  def current_position_on_path(path)
    path_users.find_by(path: path)
  end

  private

  def create_associated_step
    create_step(
      steps_until_mordor: calculate_initial_steps_to_mordor,
      steps_until_next_milestone: calculate_initial_steps_to_next_milestone
    )
  end

  def calculate_initial_steps_to_mordor
    Path.active.first&.total_distance_miles_to_steps || 0
  end

  def calculate_initial_steps_to_next_milestone
    Path.active.first&.milestones&.first&.distance_from_previous_miles_to_steps || 0
  end
end
```

### Step Model
```ruby
# app/models/step.rb
class Step < ApplicationRecord
  belongs_to :user

  validates :total_steps, :steps_today, :steps_until_mordor,
            :steps_until_next_milestone, presence: true, numericality: { greater_than_or_equal_to: 0 }

  STEPS_PER_MILE = 2112

  def can_update_today?
    last_updated_date != Date.current
  end

  def total_miles
    (total_steps / STEPS_PER_MILE.to_f).round(2)
  end

  def miles_today
    (steps_today / STEPS_PER_MILE.to_f).round(2)
  end

  def miles_until_next_milestone
    (steps_until_next_milestone / STEPS_PER_MILE.to_f).round(2)
  end

  def miles_until_mordor
    (steps_until_mordor / STEPS_PER_MILE.to_f).round(2)
  end

  def add_steps(new_steps)
    return false unless can_update_today?

    self.steps_today = new_steps
    self.total_steps += new_steps
    self.last_updated_date = Date.current

    recalculate_distances
    save
  end

  private

  def recalculate_distances
    active_path = Path.active.first
    return unless active_path

    path_user = user.current_position_on_path(active_path)
    current_milestone = path_user&.current_milestone

    if current_milestone
      remaining_distance = active_path.remaining_distance_from_milestone(current_milestone, total_miles)
      self.steps_until_mordor = (remaining_distance * STEPS_PER_MILE).to_i

      next_milestone = active_path.next_milestone_after(current_milestone)
      if next_milestone
        distance_to_next = next_milestone.cumulative_distance_miles - total_miles
        self.steps_until_next_milestone = (distance_to_next * STEPS_PER_MILE).to_i
      end
    end
  end
end
```

### Path Model
```ruby
# app/models/path.rb
class Path < ApplicationRecord
  has_many :milestones, -> { order(:sequence_order) }, dependent: :destroy
  has_many :path_users, dependent: :destroy
  has_many :users, through: :path_users

  validates :name, :part_number, :total_distance_miles, presence: true
  validates :part_number, inclusion: { in: [1, 2] }

  scope :active, -> { where(active: true) }
  scope :part_one, -> { where(part_number: 1) }
  scope :part_two, -> { where(part_number: 2) }

  def total_distance_miles_to_steps
    total_distance_miles * Step::STEPS_PER_MILE
  end

  def next_milestone_after(current_milestone)
    milestones.where('sequence_order > ?', current_milestone.sequence_order).first
  end

  def remaining_distance_from_milestone(milestone, current_user_miles)
    total_distance_miles - current_user_miles
  end

  def milestone_for_distance(miles)
    milestones.where('cumulative_distance_miles >= ?', miles).first
  end

  def all_users_completed?
    path_users.all? { |pu| pu.progress_percentage >= 100.0 }
  end
end
```

### Milestone Model
```ruby
# app/models/milestone.rb
class Milestone < ApplicationRecord
  belongs_to :path

  validates :name, :distance_from_previous_miles, :cumulative_distance_miles,
            :sequence_order, presence: true
  validates :sequence_order, uniqueness: { scope: :path_id }
  validates :map_position_x, :map_position_y, presence: true

  def distance_from_previous_miles_to_steps
    distance_from_previous_miles * Step::STEPS_PER_MILE
  end
end
```

### PathUser Model
```ruby
# app/models/path_user.rb
class PathUser < ApplicationRecord
  belongs_to :path
  belongs_to :user
  belongs_to :current_milestone, class_name: 'Milestone', optional: true

  validates :user_id, uniqueness: { scope: :path_id }

  def update_progress
    user_miles = user.total_miles
    self.current_milestone = path.milestone_for_distance(user_miles)
    self.progress_percentage = (user_miles / path.total_distance_miles.to_f * 100).round(2)
    save
  end
end
```

---

## Controllers

### SessionsController
```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    # Login modal
  end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path
  end
end
```

### StepsController
```ruby
# app/controllers/steps_controller.rb
class StepsController < ApplicationController
  before_action :require_login

  def index
    @users = User.includes(:step, path_users: [:path, :current_milestone]).all
    @active_path = Path.active.includes(:milestones).first
    @current_user_step = current_user.step
  end

  def update
    @step = current_user.step

    unless @step.can_update_today?
      return render json: {
        error: "Steps already updated today"
      }, status: :unprocessable_entity
    end

    steps_to_add = params[:steps].to_i

    if steps_to_add <= 0
      return render json: {
        error: "Steps must be greater than 0"
      }, status: :unprocessable_entity
    end

    if @step.add_steps(steps_to_add)
      update_user_path_progress

      respond_to do |format|
        format.html { redirect_to root_path, notice: "Steps updated successfully!" }
        format.json {
          render json: {
            success: true,
            step: step_json(@step),
            message: "Added #{steps_to_add} steps (#{@step.miles_today} miles)"
          }
        }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to root_path,
          alert: "Failed to update steps: #{@step.errors.full_messages.join(', ')}"
        }
        format.json {
          render json: {
            error: @step.errors.full_messages
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def admin_update
    unless current_user.admin?
      return render json: { error: "Unauthorized" }, status: :forbidden
    end

    @step = Step.find(params[:id])
    steps_to_add = params[:steps].to_i

    if @step.add_steps(steps_to_add)
      user = @step.user
      user.current_position_on_path(Path.active.first)&.update_progress

      render json: {
        success: true,
        step: step_json(@step)
      }
    else
      render json: {
        error: @step.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def update_user_path_progress
    active_path = Path.active.first
    path_user = current_user.current_position_on_path(active_path)
    path_user&.update_progress

    check_path_completion(active_path)
  end

  def check_path_completion(path)
    return unless path.all_users_completed?

    if path.part_number == 1
      # Activate Part 2 and reset user positions
      PathTransitionService.new(path).transition_to_part_two
    end
  end

  def step_json(step)
    {
      total_steps: step.total_steps,
      steps_today: step.steps_today,
      total_miles: step.total_miles,
      miles_today: step.miles_today,
      miles_until_next_milestone: step.miles_until_next_milestone,
      miles_until_mordor: step.miles_until_mordor,
      can_update_today: step.can_update_today?
    }
  end
end
```

### DashboardController
```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :require_login

  def index
    @users = User.includes(:step, path_users: [:current_milestone]).all
    @active_path = Path.active.includes(milestones: []).first
    @current_user = current_user
  end
end
```

---

## Services

### GoogleSheetsService
```ruby
# app/services/google_sheets_service.rb
require 'google/apis/sheets_v4'
require 'googleauth'

class GoogleSheetsService
  SPREADSHEET_ID = ENV['GOOGLE_SHEET_ID']
  RANGE = 'Sheet1!A2:B5' # Adjust based on your sheet structure

  def initialize
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorize
  end

  def fetch_user_steps
    response = @service.get_spreadsheet_values(SPREADSHEET_ID, RANGE)
    parse_response(response)
  rescue Google::Apis::Error => e
    Rails.logger.error("Google Sheets API error: #{e.message}")
    {}
  end

  private

  def authorize
    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(ENV['GOOGLE_SERVICE_ACCOUNT_JSON']),
      scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
    )
  end

  def parse_response(response)
    # Expected format: Column A = email, Column B = steps for today
    steps_data = {}

    response.values&.each do |row|
      email = row[0]&.strip&.downcase
      steps = row[1]&.to_i || 0

      steps_data[email] = steps if email.present? && steps > 0
    end

    steps_data
  end
end
```

### PathTransitionService
```ruby
# app/services/path_transition_service.rb
class PathTransitionService
  def initialize(current_path)
    @current_path = current_path
  end

  def transition_to_part_two
    return unless @current_path.part_number == 1

    ActiveRecord::Base.transaction do
      # Deactivate Part 1
      @current_path.update!(active: false)

      # Activate Part 2
      part_two = Path.part_two.first
      part_two.update!(active: true)

      # Reset all users to start of Part 2 (Shire)
      User.find_each do |user|
        # Maintain total_steps but reset position
        PathUser.create!(
          user: user,
          path: part_two,
          current_milestone: part_two.milestones.first,
          progress_percentage: 0.0
        )

        # Update step calculations for new path
        step = user.step
        step.update!(
          steps_until_mordor: part_two.total_distance_miles_to_steps,
          steps_until_next_milestone: part_two.milestones.second&.distance_from_previous_miles_to_steps || 0
        )
      end
    end

    Rails.logger.info("Transitioned all users from Part 1 to Part 2")
  end
end
```

### StepCalculationService
```ruby
# app/services/step_calculation_service.rb
class StepCalculationService
  STEPS_PER_MILE = 2112

  def self.miles_to_steps(miles)
    (miles * STEPS_PER_MILE).to_i
  end

  def self.steps_to_miles(steps)
    (steps / STEPS_PER_MILE.to_f).round(2)
  end
end
```

---

## Jobs

### DailyStepUpdateJob
```ruby
# app/jobs/daily_step_update_job.rb
class DailyStepUpdateJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting daily step update at #{Time.current}")

    steps_data = GoogleSheetsService.new.fetch_user_steps

    if steps_data.empty?
      Rails.logger.warn("No step data retrieved from Google Sheets")
      return
    end

    User.find_each do |user|
      next unless steps_data.key?(user.email.downcase)

      step = user.step
      next unless step.can_update_today?

      new_steps = steps_data[user.email.downcase]

      if step.add_steps(new_steps)
        # Update path progress
        active_path = Path.active.first
        path_user = user.current_position_on_path(active_path)
        path_user&.update_progress

        Rails.logger.info("Updated #{user.name}: +#{new_steps} steps")
      else
        Rails.logger.error("Failed to update #{user.name}: #{step.errors.full_messages}")
      end
    end

    # Check if we need to transition to Part 2
    active_path = Path.active.first
    if active_path&.all_users_completed? && active_path.part_number == 1
      PathTransitionService.new(active_path).transition_to_part_two
    end

    Rails.logger.info("Daily step update completed")
  end
end
```

---

## Seeds File

```ruby
# db/seeds.rb

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
  { name: "Shire", distance: 0, cumulative: 0, x: 10, y: 80 },
  { name: "Rivendell", distance: 458, cumulative: 458, x: 25, y: 60 },
  { name: "Moria", distance: 200, cumulative: 658, x: 35, y: 55 },
  { name: "Lothlórien", distance: 112, cumulative: 770, x: 45, y: 50 },
  { name: "Falls of Rauros", distance: 389, cumulative: 1159, x: 60, y: 45 },
  { name: "Dead Marshes", distance: 90, cumulative: 1249, x: 75, y: 35 },
  { name: "Shelob's Lair", distance: 80, cumulative: 1329, x: 85, y: 25 },
  { name: "Mount Doom", distance: 21, cumulative: 1350, x: 90, y: 20 }
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
  { name: "Shire", distance: 0, cumulative: 0, x: 10, y: 80 },
  { name: "Grey Havens", distance: 200, cumulative: 200, x: 5, y: 60 }
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
  { name: "Frodo", email: "frodo@shire.me", admin: true, color: "#4169E1" },
  { name: "Sam", email: "sam@shire.me", admin: false, color: "#FFD700" },
  { name: "Merry", email: "merry@shire.me", admin: false, color: "#32CD32" },
  { name: "Pippin", email: "pippin@shire.me", admin: false, color: "#FF6347" }
]

users_data.each do |user_data|
  user = User.create!(
    name: user_data[:name],
    email: user_data[:email],
    password: "password123",
    password_confirmation: "password123",
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
puts "Login with any user email and password: password123"
puts "Admin user: frodo@shire.me"
```

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root 'dashboard#index'

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  resources :steps, only: [:index, :update] do
    member do
      patch :admin_update
    end
  end

  # Health check for Heroku
  get 'up', to: 'rails/health#show', as: :rails_health_check
end
```

---

## ApplicationController

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  before_action :require_login

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: "You must be logged in to access this page"
    end
  end
end
```

---

## Scheduled Job Setup

### Clock Process for Heroku
```ruby
# lib/clock.rb
require 'clockwork'
require 'active_support/time'

module Clockwork
  configure do |config|
    config[:tz] = 'America/Chicago' # CST
  end

  # Run at 11:59 PM CST daily
  every(1.day, 'daily.step.update', at: '23:59') do
    DailyStepUpdateJob.perform_later
  end
end
```

### Procfile
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq
clock: bundle exec clockwork lib/clock.rb
```

---

## Heroku Configuration

### Required Environment Variables
```bash
# Google Sheets Integration
GOOGLE_SHEET_ID=your_sheet_id_here
GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

# Rails
RAILS_MASTER_KEY=your_master_key_here
SECRET_KEY_BASE=your_secret_key_base_here

# Database (automatically set by Heroku Postgres)
DATABASE_URL=postgresql://...

# Redis (for Sidekiq)
REDIS_URL=redis://...
```

### Heroku Setup Commands
```bash
# Create app
heroku create your-lotr-app-name

# Add Postgres
heroku addons:create heroku-postgresql:essential-0

# Add Redis for Sidekiq
heroku addons:create heroku-redis:mini

# Set environment variables
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
heroku config:set GOOGLE_SHEET_ID=your_sheet_id
heroku config:set GOOGLE_SERVICE_ACCOUNT_JSON='paste_json_here'

# Deploy
git push heroku main

# Run migrations and seed
heroku run rails db:migrate
heroku run rails db:seed

# Scale dynos
heroku ps:scale web=1 worker=1 clock=1
```

---

## Gemfile Additions

```ruby
# Add to your Gemfile

# Authentication
gem 'bcrypt', '~> 3.1.7'

# Background jobs
gem 'sidekiq', '~> 7.0'

# Scheduled jobs
gem 'clockwork', '~> 3.0'

# Google Sheets API
gem 'google-api-client', '~> 0.53'

# For Heroku
gem 'puma', '~> 6.0'

group :production do
  gem 'pg', '~> 1.5'
end
```

---

## Frontend Implementation Notes

### Dashboard View Structure
```erb
<!-- app/views/dashboard/index.html.erb -->
<div class="flex h-screen">
  <!-- Map Section (75% width) -->
  <div class="w-3/4 relative bg-gradient-to-br from-green-900 to-green-700 p-8">
    <%= render 'map', path: @active_path, users: @users %>
  </div>

  <!-- User Stats Section (25% width) -->
  <div class="w-1/4 bg-gray-900 text-white p-6 overflow-y-auto">
    <%= render 'user_stats', users: @users, current_user: @current_user %>
  </div>
</div>
```

### Map Rendering Considerations
- Use SVG for the path and milestone markers
- CSS animations for token movement
- JavaScript to update token positions based on progress_percentage
- Turbo Streams for real-time updates when steps are added

#### How to make map
- Map Display: Uses your map_of_middle_earth.svg as the background image
- SVG Overlay Layer: A transparent SVG layer on top of the map that displays:

- The journey path connecting all milestones (brown dashed line)
- Milestone markers (red circles with gold borders) positioned at specific coordinates
- User tokens (colored circles with initials) that move along the path

#### Helper Methods:

- path_coordinates() - Generates the SVG path connecting all milestones
- calculate_token_position() - Interpolates each user's exact position between milestones based on their progress


#### Positioning System:

- Milestones have map_position_x and map_position_y coordinates (0-100 scale)
- You'll need to adjust these coordinates in the seeds file to match actual locations on your SVG map
- User tokens are offset slightly vertically so they don't overlap

#### To get the coordinates right:

- Open your SVG in a browser or editor
- Use the coordinate system (usually 0-100 or based on viewBox)
- Update the milestone coordinates in the seeds file to match actual map locations

- The tokens will smoothly animate along the path as users add steps!

### User Stats Section
- Display each user's current milestone
- Show steps/miles until next milestone
- Input field (disabled if can_update_today? is false)
- Admin can edit any user's steps

---

## Migration Order

1. `rails g migration CreateUsers`
2. `rails g migration CreatePaths`
3. `rails g migration CreateMilestones`
4. `rails g migration CreateSteps`
5. `rails g migration CreatePathUsers`

---

## Testing Strategy

### Key Test Cases
- Step updates only once per day
- Admin can override and update any user
- Path transition from Part 1 to Part 2 when all users complete
- Google Sheets job handles missing/invalid data
- Milestone progression calculation accuracy
- Token position updates on map

---

## Google Sheets Setup

### Expected Sheet Format
```
| Email               | Steps Today |
|---------------------|-------------|
| frodo@shire.me      | 5000        |
| sam@shire.me        | 6200        |
| merry@shire.me      | 4800        |
| pippin@shire.me     | 7100        |
```

### Service Account Setup
1. Create a Google Cloud Project
2. Enable Google Sheets API
3. Create a Service Account
4. Generate JSON key
5. Share your Google Sheet with the service account email
6. Store JSON key in `GOOGLE_SERVICE_ACCOUNT_JSON` env var

---

## Development Workflow

1. Clone repo and bundle install
2. Set up `.env` file with required variables
3. Run `rails db:create db:migrate db:seed`
4. Start server: `rails s`
5. Start Sidekiq: `bundle exec sidekiq`
6. Login with: `frodo@shire.me` / `password123`

---

## Future Enhancements
- Email notifications when reaching milestones
- Leaderboard/competitive features
- Mobile-responsive design
- Historical step chart/graphs
- Achievement badges
- Weather/terrain effects on the map
