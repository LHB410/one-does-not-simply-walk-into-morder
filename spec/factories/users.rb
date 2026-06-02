FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@shire.me" }
    password { "password123" }
    password_confirmation { "password123" }
    admin { false }
    token_color { "#4169E1" }
    transient do
      skip_create_step { false }
    end

    trait :admin do
      admin { true }
    end

    # A group member authenticates against the group's shared password and has
    # no individual password of their own.
    trait :group_member do
      association :group
      password { nil }
      password_confirmation { nil }
    end

    # A group member who is also their group's leader.
    trait :group_leader do
      group_member

      after(:create) do |user, _evaluator|
        user.group.update!(leader: user)
      end
    end

    after(:create) do |user, evaluator|
      create(:step, user: user) unless user.step || evaluator.skip_create_step
    end
  end
end
