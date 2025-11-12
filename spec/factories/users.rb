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

    after(:create) do |user, evaluator|
      create(:step, user: user) unless user.step || evaluator.skip_create_step
    end
  end
end
