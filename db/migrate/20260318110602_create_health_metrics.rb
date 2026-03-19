class CreateHealthMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :health_metrics do |t|
      t.references :user, null: false, foreign_key: true
      t.string :metric_type
      t.float :score
      t.text :notes
      t.datetime :recorded_at

      t.timestamps
    end
  end
end
