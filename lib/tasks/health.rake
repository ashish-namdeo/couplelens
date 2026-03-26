namespace :health do
  desc "Calculate health scores for all active users with recent activity"
  task calculate_all: :environment do
    puts "🏥 Starting health score calculation for all users..."

    users = User.where(role: :couple_member)
                .where("telegram_id IS NOT NULL OR whatsapp_id IS NOT NULL")

    total = users.count
    success = 0
    skipped = 0
    errors = 0

    users.find_each.with_index do |user, index|
      print "\r  Processing #{index + 1}/#{total}: #{user.email}..."

      calculator = HealthScoreCalculatorService.new(user)
      result = calculator.calculate!

      if result
        success += 1
      else
        skipped += 1
      end
    rescue => e
      errors += 1
      puts "\n  ❌ Error for #{user.email}: #{e.message}"
    end

    puts "\n\n✅ Health score calculation complete!"
    puts "   Total users: #{total}"
    puts "   Scored: #{success}"
    puts "   Skipped (no data): #{skipped}"
    puts "   Errors: #{errors}"
  end

  desc "Calculate health scores for a specific user. Usage: rails health:calculate_for USER_ID=1"
  task calculate_for: :environment do
    user_id = ENV["USER_ID"]
    abort "❌ Please provide USER_ID=<id>" if user_id.blank?

    user = User.find(user_id)
    puts "🏥 Calculating health scores for #{user.email}..."

    calculator = HealthScoreCalculatorService.new(user)
    result = calculator.calculate!

    if result
      puts "✅ Scores calculated:"
      result.each do |type, data|
        puts "   #{type.titleize}: #{data[:score]} — #{data[:note]}"
      end
    else
      puts "⚠️  Not enough activity data for this user."
    end
  end
end
