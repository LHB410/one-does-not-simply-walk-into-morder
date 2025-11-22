# Scaling Plan: Group Model & 1000+ Users

## Part 1: Group Model Implementation

### Database Changes

1. **Create Groups Table**
   - `id` (primary key)
   - `name` (string, optional - for display purposes)
   - `password_digest` (string, required) - shared group password
   - `created_at`, `updated_at`
   - Index on `id`

2. **Modify Users Table**
   - Add `group_id` (bigint, foreign key, required)
   - Add index on `group_id`
   - Remove `password_digest` from users (groups share password)
   - Keep `email` unique within group scope (or globally - see decision below)

3. **Add Group Membership Validation**
   - Limit 20 users per group
   - Enforce at model level with custom validation

### Authentication Flow Changes

**Current Flow:**
- User provides email + password
- System authenticates user's password

**New Flow:**
- User provides email + password
- System finds user by email
- System authenticates against user's group password (not user password)
- Session stores `user_id` (same as before)

### Model Changes

**Group Model:**
```ruby
class Group < ApplicationRecord
  has_secure_password
  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true, allow_blank: true
  validate :user_count_limit

  def user_count_limit
    if users.size > 20
      errors.add(:users, "cannot exceed 20 members")
    end
  end
end
```

**User Model Changes:**
- Add `belongs_to :group`
- Remove `has_secure_password`
- Update validations to ensure email uniqueness (either globally or within group)
- Add validation to prevent group from exceeding 20 users

**Sessions Controller Changes:**
- Find user by email
- Authenticate password against `user.group` instead of `user`

### Migration Strategy

1. Create groups table
2. Create a default group for existing users (or migrate existing users)
3. Add group_id to users
4. Remove password_digest from users (or keep for migration period)
5. Update authentication logic
6. Add validations

---

## Part 2: Scaling to 1000+ Users

### Critical Improvements Needed

#### 1. Database Optimization

**Indexing:**
- ✅ Already have: `users.email`, `path_users(path_id, user_id)`, `steps.user_id`
- ⚠️ **Add:**
  - `groups.id` (primary key - automatic)
  - `users.group_id` (foreign key index)
  - `steps.last_updated_date` (for daily job filtering)
  - `path_users.progress_percentage` (for completion queries)
  - Composite index on `(path_id, progress_percentage)` if querying by path + progress

**Query Optimization:**
- **Dashboard Controller:** Currently loads ALL users with `User.all`. For 1000+ users:
  - Add pagination (e.g., 50 users per page)
  - Consider lazy loading or infinite scroll
  - Add scopes for filtering (by group, by progress, etc.)
  - Use counter caches for group user counts

**N+1 Query Prevention:**
- Current code uses `includes()` which is good
- Monitor with tools like `bullet` gem
- Consider using `preload` vs `includes` based on query patterns

#### 2. Caching Strategy

**Application-Level Caching:**
- Cache `Path.current` (already memoized, but consider Redis for multi-server)
- Cache user stats/aggregations
- Cache group member lists
- Use fragment caching for dashboard views

**Redis Integration:**
- Session storage (move from cookie-based to Redis)
- Cache frequently accessed data
- Rate limiting counters
- Background job queues (if not already using Redis)

**Cache Invalidation:**
- Clear relevant caches when steps update
- Clear group caches when membership changes

#### 3. Background Job Optimization

**Current Job (DailyStepUpdateJob):**
- Uses `find_each` (good for batching)
- Processes all users sequentially

**Improvements:**
- **Parallel Processing:** Process users in batches (e.g., 100 at a time, 5 parallel workers)
- **Selective Updates:** Only process users in groups that have activity
- **Job Scheduling:** Use `sidekiq-cron` or similar for reliable scheduling
- **Error Handling:** Add retry logic with exponential backoff
- **Monitoring:** Track job duration, success rates, failures

**Example Optimization:**
```ruby
# Process in parallel batches
User.includes(:step, path_users: :path)
  .where(group_id: active_groups)
  .find_in_batches(batch_size: 100) do |batch|
    # Process batch in parallel
  end
```

#### 4. Pagination & Lazy Loading

**Dashboard:**
- Implement pagination (Kaminari or pagy gem)
- Default to showing user's group first
- Add filters: "My Group", "All Users", "By Progress"
- Use infinite scroll or "Load More" for better UX

**API Endpoints (if adding):**
- Add pagination to all list endpoints
- Use cursor-based pagination for large datasets

#### 5. Database Connection Pooling

**Current:** Rails default (usually 5 connections)

**For 1000+ Users:**
- Increase `pool` size in `database.yml`
- Monitor connection usage
- Consider using PgBouncer for connection pooling at database level
- Use read replicas for read-heavy operations (dashboard views)

#### 6. Asset & Static Content

**CDN:**
- Serve static assets (images, CSS, JS) via CDN
- Use CloudFront, Cloudflare, or similar
- Cache map images and other static content

**Asset Optimization:**
- Minify CSS/JS
- Compress images (SVG optimization)
- Use WebP format where possible

#### 7. Monitoring & Observability

**Essential Tools:**
- **APM:** New Relic, Datadog, or Skylight
- **Error Tracking:** Sentry or Rollbar
- **Logging:** Structured logging (JSON format)
- **Database Monitoring:** pg_stat_statements, slow query logs
- **Uptime Monitoring:** Pingdom, UptimeRobot

**Key Metrics to Track:**
- Response times (p50, p95, p99)
- Database query times
- Background job duration
- Error rates
- Active users per day
- Database connection pool usage

#### 8. Rate Limiting

**Protect Against:**
- Brute force login attempts
- API abuse (if adding API)
- Step update spam

**Implementation:**
- Use `rack-attack` gem
- Limit login attempts per IP/email
- Limit step updates per user per day (already have some protection)

#### 9. Security Enhancements

**For Multi-Group Environment:**
- Ensure users can only see their group's data (authorization)
- Add `can?` methods or Pundit policies
- Audit logging for sensitive actions
- CSRF protection (Rails default, but verify)

**Password Security:**
- Group passwords should be strong (enforce complexity)
- Consider password rotation policies
- Add 2FA for group admins (optional)

#### 10. Database Maintenance

**Regular Tasks:**
- Vacuum and analyze PostgreSQL tables
- Monitor table bloat
- Archive old data (if needed)
- Regular backups with point-in-time recovery

**Partitioning (if needed at larger scale):**
- Consider partitioning `steps` table by date if it grows very large
- Partition `path_users` if tracking historical progress

#### 11. Horizontal Scaling Preparation

**Application Servers:**
- Stateless application design (✅ already using sessions)
- Use Redis for shared session storage
- Load balancer (AWS ALB, nginx, etc.)
- Health checks for each server

**Database:**
- Read replicas for read-heavy operations
- Connection pooling (PgBouncer)
- Consider database sharding by group (advanced, only if needed)

#### 12. Code-Specific Optimizations

**Dashboard Controller:**
```ruby
# Current: Loads all users
@users = User.includes(:step, path_users: [:current_milestone, :path, user: :step]).all

# Optimized: Paginate and scope to current user's group
@users = current_user.group.users
  .includes(:step, path_users: [:current_milestone, :path])
  .page(params[:page])
  .per(50)
```

**Path.current Caching:**
- Current memoization is good for single server
- For multi-server: use Redis cache
- Cache key: `"path:current"` with TTL

**Step Calculations:**
- Consider materialized views for aggregated stats
- Pre-calculate common queries (group totals, leaderboards)

### Priority Order for Implementation

**Phase 1 (Critical - Do First):**
1. Add database indexes
2. Implement pagination on dashboard
3. Add Redis for caching and sessions
4. Optimize DailyStepUpdateJob (parallel processing)
5. Add monitoring (APM, error tracking)

**Phase 2 (Important - Do Soon):**
6. Implement rate limiting
7. Add authorization checks (group scoping)
8. CDN for static assets
9. Database connection pooling
10. Query optimization audit

**Phase 3 (Nice to Have - As Needed):**
11. Read replicas
12. Advanced caching strategies
13. Database partitioning
14. Horizontal scaling setup

### Testing at Scale

**Load Testing:**
- Use tools like `k6`, `Apache Bench`, or `wrk`
- Test with 1000+ concurrent users
- Monitor database performance under load
- Test background job processing under load

**Database Testing:**
- Test query performance with large datasets
- Use `EXPLAIN ANALYZE` on slow queries
- Test index effectiveness

---

## Implementation Checklist

### Group Model
- [ ] Create groups migration
- [ ] Create Group model with validations
- [ ] Add group_id to users migration
- [ ] Update User model (belongs_to :group, remove has_secure_password)
- [ ] Update SessionsController to authenticate against group password
- [ ] Add group membership limit validation (20 users)
- [ ] Update dashboard to scope by group (optional: show all groups for admins)
- [ ] Add group management UI (create groups, manage members)
- [ ] Migration script for existing users
- [ ] Update tests

### Scaling Improvements
- [ ] Add database indexes
- [ ] Implement pagination
- [ ] Set up Redis
- [ ] Optimize background jobs
- [ ] Add monitoring
- [ ] Implement rate limiting
- [ ] Add authorization checks
- [ ] Set up CDN
- [ ] Configure connection pooling
- [ ] Load testing

---

## Estimated Impact

**Current Capacity:** ~100-200 users comfortably

**After Group Model:** Same capacity, but better organization

**After Scaling Improvements:** 1000+ users with good performance

**After Full Optimization:** 5000+ users with proper infrastructure

