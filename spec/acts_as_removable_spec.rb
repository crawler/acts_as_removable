# frozen_string_literal: true

require 'spec_helper'

describe 'acts_as_removable' do
  class MyModel < ActiveRecord::Base
    acts_as_removable
    attr_accessor :callback_before_remove, :callback_after_remove, :callback_before_unremove, :callback_after_unremove
    before_remove do |r|
      r.callback_before_remove = true
    end
    after_remove do |r|
      r.callback_after_remove = true
    end

    before_unremove do |ur|
      ur.callback_before_unremove = true
    end
    after_unremove do |ur|
      ur.callback_after_unremove = true
    end
  end

  class MySecondModel < ActiveRecord::Base
    acts_as_removable column_name: :use_this_column
  end

  before :all do
    # setup database
    db_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'tmp', 'acts_as_removable.db'))
    Dir.mkdir(File.dirname(db_file)) unless File.exist?(File.dirname(db_file))
    ActiveRecord::Base.establish_connection(
      adapter:  'sqlite3',
      database: "#{File.expand_path(File.join(File.dirname(__FILE__), '..'))}/tmp/acts_as_removable.db"
    )
    ActiveRecord::Base.connection.create_table(:my_models, force: true) do |t|
      t.timestamp :removed_at
    end
    ActiveRecord::Base.connection.create_table(:my_second_models, force: true) do |t|
      t.string :name
      t.timestamp :use_this_column
    end
    ActiveRecord::Base.connection.create_table(:other_models, force: true)
  end

  it 'should be removable' do
    expect(MyModel).to be_removable
    expect(MyModel.new).to be_removable
  end

  it 'test column and check method' do
    [[MyModel.create!, :removed_at], [MySecondModel.create!, :use_this_column]].each do |r, column_name|
      expect(r.removed?).to be(false)
      expect(r.send(column_name)).to be(nil)

      r.remove
      expect(r.removed?).to be(true)
      expect(r.send(column_name)).to be_kind_of(Time)
    end
  end

  it 'test scopes' do
    MyModel.delete_all
    MySecondModel.delete_all

    MyModel.create!
    MyModel.create!.remove!
    MySecondModel.create!
    MySecondModel.create!.remove!

    expect(MyModel.count).to be(2)
    expect(MyModel.present.count).to be(1)
    expect(MyModel.removed.count).to be(1)
    expect(MyModel.unscoped.count).to be(2)

    expect(MySecondModel.count).to be(2)
    expect(MySecondModel.present.count).to be(1)
    expect(MySecondModel.removed.count).to be(1)
    expect(MySecondModel.unscoped.count).to be(2)
  end

  it 'test callbacks' do
    r = MyModel.create!
    expect(r.callback_before_remove).to be(nil)
    expect(r.callback_after_remove).to be(nil)
    expect(r.callback_before_unremove).to be(nil)
    expect(r.callback_after_unremove).to be(nil)

    r.remove

    expect(r.callback_before_remove).to be(true)
    expect(r.callback_after_remove).to be(true)
    expect(r.callback_before_unremove).to be(nil)
    expect(r.callback_after_unremove).to be(nil)

    r.unremove

    expect(r.callback_before_remove).to be(true)
    expect(r.callback_after_remove).to be(true)
    expect(r.callback_before_unremove).to be(true)
    expect(r.callback_after_unremove).to be(true)
  end

  context 'validate: true option' do
    class Invalid < ActiveRecord::Base
      acts_as_removable validate: true
      validates :name, presence: true
    end

    subject do
      Invalid.new.tap { |r| r.save(validate: false) }
    end

    before do
      ActiveRecord::Base.connection.create_table(:invalids, force: true) do |t|
        t.string :name
        t.timestamp :removed_at
      end
    end

    it 'should not remove' do
      expect(subject.remove).to be(false)
      expect(subject.reload.removed_at).to be(nil)
      expect(subject.removed?).to be(false)
    end

    it 'should raise error' do
      expect { subject.remove! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(subject.reload.removed_at).to be(nil)
      expect(subject.removed?).to be(false)
    end
  end

  context 'other models' do
    class OtherModel < ActiveRecord::Base
    end

    subject { OtherModel }

    before :all do
      ActiveRecord::Base.connection.create_table(:other_models, force: true) do |t|
        t.string :name
        t.timestamp :removed_at
      end
    end

    it 'should not be removable' do
      expect(subject).to_not be_removable
      expect(subject.new).to_not be_removable
    end
  end
end
