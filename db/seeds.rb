puts "🌱 Seeding CoupleLens database..."

# Create Admin
admin = User.create!(
  email: 'admin@couplelens.com',
  password: 'password123',
  first_name: 'Admin',
  last_name: 'User',
  role: :admin
)
puts "✅ Admin created: admin@couplelens.com / password123"

# Create Demo User
user = User.create!(
  email: 'demo@couplelens.com',
  password: 'password123',
  first_name: 'Sarah',
  last_name: 'Johnson',
  role: :couple_member
)
puts "✅ Demo user created: demo@couplelens.com / password123"

# Create Therapist Users & Profiles
therapist_data = [
  { first: 'Dr. Emily', last: 'Chen', spec: 'Gottman Method', bio: 'Certified Gottman Method Couples Therapist with 12 years of experience helping couples build stronger relationships through research-based interventions.', rate: 150, exp: 12, rating: 4.9 },
  { first: 'Dr. Marcus', last: 'Williams', spec: 'Emotionally Focused Therapy (EFT)', bio: 'EFT-certified therapist specializing in attachment-based interventions. Passionate about helping couples deepen their emotional bonds.', rate: 175, exp: 15, rating: 4.8 },
  { first: 'Dr. Priya', last: 'Patel', spec: 'Cognitive Behavioral Therapy (CBT)', bio: 'CBT specialist helping couples identify and change negative thinking patterns that damage relationships.', rate: 130, exp: 8, rating: 4.7 },
  { first: 'Dr. James', last: 'Anderson', spec: 'Imago Relationship Therapy', bio: 'Imago therapist focused on helping couples understand how childhood experiences shape current relationship dynamics.', rate: 160, exp: 20, rating: 4.9 },
  { first: 'Dr. Sofia', last: 'Martinez', spec: 'Narrative Therapy', bio: 'Narrative therapist helping couples rewrite their relationship stories and rediscover their strengths as partners.', rate: 140, exp: 10, rating: 4.6 },
  { first: 'Dr. David', last: 'Kim', spec: 'Solution-Focused Therapy', bio: 'Solution-focused therapist who helps couples move quickly from problems to solutions with practical strategies.', rate: 120, exp: 7, rating: 4.5 },
]

therapist_data.each do |td|
  t_user = User.create!(
    email: "#{td[:first].parameterize}@therapy.com",
    password: 'password123',
    first_name: td[:first],
    last_name: td[:last],
    role: :therapist
  )
  TherapistProfile.create!(
    user: t_user,
    specialization: td[:spec],
    bio: td[:bio],
    hourly_rate: td[:rate],
    years_experience: td[:exp],
    rating: td[:rating],
    status: :approved,
    certifications: "Licensed Professional Counselor (LPC), #{td[:spec]} Certified"
  )
end
puts "✅ #{therapist_data.length} therapists created"

# Health Metrics for demo user
metrics = %w[communication trust conflict_resolution intimacy shared_goals]
30.times do |i|
  date = (30 - i).days.ago
  metrics.each do |m|
    HealthMetric.create!(
      user: user,
      metric_type: m,
      score: rand(45.0..92.0).round(1),
      notes: ["Weekly check-in", "After therapy session", "Self-assessment", "Triggered by conversation", nil].sample,
      recorded_at: date
    )
  end
end
puts "✅ Health metrics seeded"

# Sample Conversations
conv1 = Conversation.create!(user: user, title: 'Communication Tips', persona: 'communication_expert', status: :active)
conv1.messages.create!(role: 'system', content: 'You are a communication expert.')
conv1.messages.create!(role: 'user', content: 'My partner and I keep having the same argument about chores. How can we break this cycle?')
conv1.messages.create!(role: 'assistant', content: "That's a common communication pattern called 'demand-withdraw.' One partner pushes for discussion while the other pulls away. Let's practice the 'soft startup' technique to break this cycle. Instead of saying 'You never help around the house,' try: 'I feel overwhelmed with housework and I'd love your help with specific tasks. Could we create a plan together?'")

conv2 = Conversation.create!(user: user, title: 'Trust Building', persona: 'empathetic_listener', status: :active)
conv2.messages.create!(role: 'system', content: 'You are an empathetic listener.')
conv2.messages.create!(role: 'user', content: "I've been feeling disconnected from my partner lately.")
conv2.messages.create!(role: 'assistant', content: "I hear you, and I want you to know that what you're feeling is completely valid. Feeling disconnected is one of the most common experiences couples face, especially during busy or stressful periods. Tell me more — what does this disconnection feel like for you?")
puts "✅ Sample conversations created"

# Conflict Session
cs = ConflictSession.create!(
  user: user,
  partner_name: 'Michael',
  topic: 'Division of household responsibilities',
  user_perspective: "I feel like I'm doing most of the housework and it's exhausting. When I bring it up, Michael says he does plenty but I don't notice. I just want things to be fair.",
  partner_perspective: "I do a lot of things that Sarah doesn't see — managing finances, fixing things around the house, handling insurance. The problem is we value different types of contributions differently.",
  status: :completed,
  ai_analysis: "Both partners bring valid perspectives. Sarah values visible, daily contributions while Michael focuses on behind-the-scenes management. The core issue is recognition, not effort.",
  ai_summary: "Both partners contribute significantly but in different ways. Creating a complete inventory of responsibilities and discussing definitions of 'fair' will help resolve this."
)
puts "✅ Conflict session created"

# Compatibility Assessment
CompatibilityAssessment.create!(
  user: user,
  partner_name: 'Michael',
  financial_score: 82.5,
  lifestyle_score: 89.3,
  parenting_score: 75.8,
  overall_score: 82.5,
  status: :completed,
  strengths: "Strong emotional connection and mutual empathy\n• Aligned long-term life goals and vision\n• Excellent conflict resolution skills\n• Shared values around family and community",
  risk_areas: "Different approaches to financial planning\n• Varying expectations around work-life balance\n• Communication gaps during high-stress periods",
  full_report: "Your compatibility is strong at 82.5%. Continue nurturing your communication skills and schedule regular check-ins."
)
puts "✅ Compatibility assessment created"

# Expenses
categories = %w[Housing Food Transportation Entertainment Health Shopping Travel]
20.times do |i|
  Expense.create!(
    user: user,
    category: categories.sample,
    amount: rand(10.0..500.0).round(2),
    description: ["Groceries", "Dinner out", "Movie tickets", "Gas", "Gym membership", "New shoes", "Uber ride", "Coffee", "Rent", "Electric bill"].sample,
    expense_date: rand(0..30).days.ago.to_date,
    shared: [true, false].sample
  )
end
puts "✅ Expenses created"

# Memories
memories = [
  { title: 'Our First Date', type: 'milestone', date: '2024-03-15', desc: 'Coffee at that little place downtown. We talked for 4 hours and didn\'t notice time passing.' },
  { title: 'Weekend in the Mountains', type: 'trip', date: '2024-07-20', desc: 'Hiked to the summit and watched the sunset. One of our best adventures.' },
  { title: '1 Year Anniversary', type: 'anniversary', date: '2025-03-15', desc: 'Celebrated with dinner at Chez Laurent. Best night ever. 💕' },
  { title: 'Surprise Birthday Party', type: 'surprise', date: '2025-06-12', desc: 'Planned a surprise party with all our friends. The look on his face was priceless!' },
  { title: 'Cooking Class Date Night', type: 'date_night', date: '2025-09-08', desc: 'Took an Italian cooking class together. Made the best pasta from scratch.' },
  { title: 'Moved In Together', type: 'milestone', date: '2025-11-01', desc: 'Finally moved into our first apartment together. New chapter begins! 🏠' },
]
memories.each do |m|
  Memory.create!(user: user, title: m[:title], memory_type: m[:type], memory_date: m[:date], description: m[:desc])
end
puts "✅ Memories created"

# Programs
programs = [
  { title: 'Trust Rebuilding Program', desc: 'A structured 8-week program designed to help couples rebuild trust after breaches. Includes guided exercises, journaling prompts, and communication techniques.', cat: 'Trust Rebuilding', diff: 'Intermediate', weeks: 8 },
  { title: 'Pre-Marriage Preparation', desc: 'Comprehensive course covering communication, finances, conflict resolution, and intimacy expectations for engaged couples.', cat: 'Pre-Marriage Preparation', diff: 'Beginner', weeks: 6 },
  { title: 'Communication Mastery', desc: 'Learn advanced communication techniques including active listening, nonviolent communication, and emotional intelligence.', cat: 'Communication Skills', diff: 'Advanced', weeks: 4 },
  { title: 'Conflict to Connection', desc: 'Transform conflicts into opportunities for deeper connection. Learn the Gottman method of processing disagreements.', cat: 'Conflict Resolution', diff: 'Intermediate', weeks: 5 },
]
programs.each do |p|
  prog = Program.create!(title: p[:title], description: p[:desc], category: p[:cat], difficulty: p[:diff], duration_weeks: p[:weeks], status: :published)
  rand(4..8).times do |i|
    Lesson.create!(
      program: prog,
      title: "Lesson #{i + 1}: #{['Understanding the Basics', 'Building Foundation', 'Core Techniques', 'Practice Exercises', 'Advanced Strategies', 'Real-World Application', 'Review & Reflect', 'Moving Forward'].sample}",
      content: "This lesson covers essential concepts for #{p[:cat].downcase}. You'll learn practical techniques and complete guided exercises to strengthen your relationship.",
      position: i + 1,
      lesson_type: ['reading', 'video', 'exercise', 'quiz'].sample
    )
  end
end
puts "✅ Programs created"

# Workshops
workshops = [
  { title: 'Weekend Couples Retreat: Reconnect', desc: 'An immersive weekend retreat focused on deepening your emotional bond. Includes guided activities, workshops, and private couple time.', instructor: 'Dr. Emily Chen', location: 'Sedona, Arizona', date: 45.days.from_now, price: 799, cap: 20, type: 'retreat' },
  { title: 'Communication Workshop: Speaking from the Heart', desc: 'A half-day workshop teaching couples essential communication skills using evidence-based techniques.', instructor: 'Dr. Marcus Williams', location: 'Online via Zoom', date: 14.days.from_now, price: 149, cap: 50, type: 'online' },
  { title: 'Financial Harmony: Money Talk Workshop', desc: 'Learn to discuss finances without conflict. Covers budgeting, financial goals, and money personalities.', instructor: 'Dr. Priya Patel', location: 'New York, NY', date: 30.days.from_now, price: 199, cap: 30, type: 'in_person' },
  { title: 'Intimate Connection Weekend', desc: 'Explore emotional and physical intimacy in a safe, guided environment. For couples at any stage.', instructor: 'Dr. Sofia Martinez', location: 'Napa Valley, CA', date: 60.days.from_now, price: 999, cap: 15, type: 'retreat' },
]
workshops.each do |w|
  Workshop.create!(title: w[:title], description: w[:desc], instructor: w[:instructor], location: w[:location], workshop_date: w[:date], price: w[:price], capacity: w[:cap], spots_taken: rand(0..w[:cap]/2), workshop_type: w[:type], status: :upcoming)
end
puts "✅ Workshops created"

# Therapist Application (pending)
TherapistApplication.create!(
  user: User.create!(email: 'pending@therapy.com', password: 'password123', first_name: 'Dr. Rachel', last_name: 'Green', role: :couple_member),
  full_name: 'Dr. Rachel Green',
  email: 'rachel.green@therapy.com',
  specialization: 'General Couples Therapy',
  bio: 'Licensed therapist with 5 years experience in couples and family therapy. Passionate about helping couples communicate better.',
  certifications: 'PhD in Clinical Psychology, Licensed Marriage and Family Therapist (LMFT)',
  years_experience: 5,
  hourly_rate: 110,
  status: :submitted
)
puts "✅ Pending therapist application created"

puts ""
puts "🎉 Seeding complete!"
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
puts "📧 Admin:     admin@couplelens.com / password123"
puts "📧 Demo User: demo@couplelens.com  / password123"
puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
