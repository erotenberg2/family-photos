# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create AdminUser for backend management
AdminUser.find_or_create_by!(email: 'admin@example.com') do |admin|
  admin.password = 'password'
  admin.password_confirmation = 'password'
end if Rails.env.development?

# Create Users with different family roles
if Rails.env.development?
  # Family Admin - can manage everything
  User.find_or_create_by!(email: 'dad@family.com') do |user|
    user.first_name = 'John'
    user.last_name = 'Smith'
    user.role = 'family_admin'
    user.password = 'password'
    user.password_confirmation = 'password'
    user.active = true
  end

  # Photo Admin - can manage photos and albums
  User.find_or_create_by!(email: 'mom@family.com') do |user|
    user.first_name = 'Jane'
    user.last_name = 'Smith'
    user.role = 'photo_admin'
    user.password = 'password'
    user.password_confirmation = 'password'
    user.active = true
  end

  # Family Members - can upload photos
  User.find_or_create_by!(email: 'alice@family.com') do |user|
    user.first_name = 'Alice'
    user.last_name = 'Smith'
    user.role = 'family_member'
    user.password = 'password'
    user.password_confirmation = 'password'
    user.active = true
  end

  User.find_or_create_by!(email: 'bob@family.com') do |user|
    user.first_name = 'Bob'
    user.last_name = 'Smith'
    user.role = 'family_member'
    user.password = 'password'
    user.password_confirmation = 'password'
    user.active = true
  end

  # Inactive family member example
  User.find_or_create_by!(email: 'charlie@family.com') do |user|
    user.first_name = 'Charlie'
    user.last_name = 'Smith'
    user.role = 'family_member'
    user.password = 'password'
    user.password_confirmation = 'password'
    user.active = false
  end

  puts "Created #{User.count} users:"
  User.all.each do |user|
    puts "  - #{user.display_name} (#{user.email}) - #{user.role_display} - #{user.status_display}"
  end
end