# Terminal Commands for LOTR Step Tracker

## Order of Execution

### Step 1: Create Models (and their migrations)

Models should be created in dependency order:

```bash
# 1. User model (no dependencies)
rails generate model User name:string email:string:index password_digest:string admin:boolean token_color:string

# 2. Path model (no dependencies)
rails generate model Path name:string part_number:integer total_distance_miles:integer active:boolean

# 3. Milestone model (depends on Path)
rails generate model Milestone path:references name:string distance_from_previous_miles:integer cumulative_distance_miles:integer sequence_order:integer map_position_x:decimal map_position_y:decimal

# 4. Step model (depends on User)
rails generate model Step user:references total_steps:integer steps_today:integer steps_until_mordor:integer steps_until_next_milestone:integer last_updated_date:date

# 5. PathUser model (depends on Path, User, and Milestone)
rails generate model PathUser path:references user:references current_milestone_id:integer progress_percentage:decimal
```

### Step 2: Modify Migrations

After generating, you'll need to edit the migration files to add:
- Unique indexes
- Default values
- Null constraints
- Composite indexes

**File: db/migrate/XXXXXX_create_users.rb**
- Add `index: { unique: true }` to email
- Add `null: false` to name, email, password_digest
- Add `default: false` to admin

**File: db/migrate/XXXXXX_create_paths.rb**
- Add `null: false` to name, part_number, total_distance_miles
- Add `default: false` to active

**File: db/migrate/XXXXXX_create_milestones.rb**
- Add `null: false` to path_id, name, distance_from_previous_miles, cumulative_distance_miles, sequence_order
- Add composite unique index: `add_index :milestones, [:path_id, :sequence_order], unique: true`

**File: db/migrate/XXXXXX_create_steps.rb**
- Add `null: false` to user_id, total_steps, steps_today, steps_until_mordor, steps_until_next_milestone
- Add `default: 0` to total_steps, steps_today
- Add unique index on user_id: `add_index :steps, :user_id, unique: true`

**File: db/migrate/XXXXXX_create_path_users.rb**
- Add `null: false` to path_id, user_id
- Add `default: 0.0` to progress_percentage
- Add composite unique index: `add_index :path_users, [:path_id, :user_id], unique: true`
- Note: current_milestone_id should remain as integer (optional foreign key, not a Rails foreign_key constraint)

### Step 3: Run Migrations

```bash
rails db:migrate
```

### Step 4: Create Controllers

```bash
# Sessions controller (authentication)
rails generate controller Sessions new create destroy

# Dashboard controller (main view)
rails generate controller Dashboard index

# Steps controller (step management)
rails generate controller Steps index update admin_update
```

### Step 5: Update Routes

Edit `config/routes.rb` to match the plan (see plan document lines 700-720)

### Step 6: Create Services Directory and Files

```bash
# Create services directory
mkdir -p app/services

# Create service files (you'll need to manually create these files with the code from the plan)
# - app/services/google_sheets_service.rb
# - app/services/path_transition_service.rb
# - app/services/step_calculation_service.rb
```

### Step 7: Create Jobs

```bash
# Create job file (you'll need to manually create this file with the code from the plan)
# - app/jobs/daily_step_update_job.rb
```

### Step 8: Seed the Database

```bash
rails db:seed
```

---

## Alternative: Using Migration Generators Only

If you prefer to create migrations first and models manually (as suggested in the plan's Migration Order section):

```bash
# 1. Create Users migration
rails generate migration CreateUsers name:string email:string password_digest:string admin:boolean token_color:string

# 2. Create Paths migration
rails generate migration CreatePaths name:string part_number:integer total_distance_miles:integer active:boolean

# 3. Create Milestones migration
rails generate migration CreateMilestones path:references name:string distance_from_previous_miles:integer cumulative_distance_miles:integer sequence_order:integer map_position_x:decimal map_position_y:decimal

# 4. Create Steps migration
rails generate migration CreateSteps user:references total_steps:integer steps_today:integer steps_until_mordor:integer steps_until_next_milestone:integer last_updated_date:date

# 5. Create PathUsers migration
rails generate migration CreatePathUsers path:references user:references current_milestone_id:integer progress_percentage:decimal

# Then manually create model files in app/models/
```

---

## Complete Command Sequence (Recommended Approach)

```bash
# 1. Generate all models
rails generate model User name:string email:string:index password_digest:string admin:boolean token_color:string
rails generate model Path name:string part_number:integer total_distance_miles:integer active:boolean
rails generate model Milestone path:references name:string distance_from_previous_miles:integer cumulative_distance_miles:integer sequence_order:integer map_position_x:decimal map_position_y:decimal
rails generate model Step user:references total_steps:integer steps_today:integer steps_until_mordor:integer steps_until_next_milestone:integer last_updated_date:date
rails generate model PathUser path:references user:references current_milestone_id:integer progress_percentage:decimal

# 2. Edit migrations to add constraints, defaults, and indexes (see Step 2 above)

# 3. Run migrations
rails db:migrate

# 4. Generate controllers
rails generate controller Sessions new create destroy
rails generate controller Dashboard index
rails generate controller Steps index update admin_update

# 5. Create services directory
mkdir -p app/services

# 6. Seed database
rails db:seed
```

---

## Notes

1. After generating models, you'll need to manually add the model code from the plan document (associations, validations, methods, etc.)
2. After generating controllers, you'll need to manually add the controller code from the plan document
3. You'll need to manually create the service files and job files with the code from the plan
4. Make sure to add `bcrypt` gem to Gemfile for password authentication
5. Update `config/routes.rb` with the routes from the plan
6. Update `app/controllers/application_controller.rb` with the authentication helpers from the plan

