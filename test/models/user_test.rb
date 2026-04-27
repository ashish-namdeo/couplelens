require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = User.new(
      first_name: "Test",
      last_name: "User",
      email: "test@example.com",
      password: "password123",
      role: :couple_member
    )
    assert user.valid?
  end

  test "should require first_name" do
    user = User.new(first_name: nil)
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "should require last_name" do
    user = User.new(last_name: nil)
    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "should require email" do
    user = User.new(email: nil)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should enforce uniqueness of email scoped by role" do
    existing_user = User.create!(
      first_name: "Existing",
      last_name: "User",
      email: "duplicate@example.com",
      password: "password123",
      role: :couple_member
    )

    duplicate_user = User.new(
      first_name: "New",
      last_name: "User",
      email: "duplicate@example.com",
      password: "password123",
      role: :couple_member
    )

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"

    different_role_user = User.new(
      first_name: "New",
      last_name: "User",
      email: "duplicate@example.com",
      password: "password123",
      role: :therapist
    )

    assert different_role_user.valid?
  end

  test "full_name should return first and last name" do
    user = User.new(first_name: "John", last_name: "Doe")
    assert_equal "John Doe", user.full_name
  end

  test "default role should be couple_member" do
    user = User.new
    assert_equal "couple_member", user.role
  end
end
