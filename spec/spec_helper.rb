# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'acts_as_removable'

TABLES = %i[first_models second_models invalids other_models].freeze

RSpec.configure do |config|
  config.before :all do
    # setup database
    db_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'tmp', 'acts_as_removable.db'))
    Dir.mkdir(File.dirname(db_file)) unless File.exist?(File.dirname(db_file))

    ActiveRecord::Base.establish_connection(
      adapter:  'sqlite3',
      database: "#{File.expand_path(File.join(File.dirname(__FILE__), '..'))}/tmp/acts_as_removable.db"
    )

    ActiveRecord::Base.connection.create_table(:first_models, force: true) do |t|
      t.timestamp :removed_at
    end

    ActiveRecord::Base.connection.create_table(:second_models, force: true) do |t|
      t.string :name
      t.timestamp :use_this_column
    end

    ActiveRecord::Base.connection.create_table(:invalids, force: true) do |t|
      t.string :name
      t.timestamp :removed_at
    end

    ActiveRecord::Base.connection.create_table(:other_models, force: true) do |t|
      t.string :name
      t.timestamp :removed_at
    end
  end

  config.after do
    TABLES.each { |table| ActiveRecord::Base.connection.execute("DELETE FROM `#{table}` WHERE 1=1") }
  end
end
