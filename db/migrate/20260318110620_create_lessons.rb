class CreateLessons < ActiveRecord::Migration[7.0]
  def change
    create_table :lessons do |t|
      t.references :program, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.integer :position
      t.string :lesson_type
      t.string :video_url

      t.timestamps
    end
  end
end
