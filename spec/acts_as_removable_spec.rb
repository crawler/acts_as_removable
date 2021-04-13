# frozen_string_literal: true

require 'spec_helper'

describe 'ActsAsRemovable' do
  let(:first_model) do
    Class.new(ActiveRecord::Base) do |model|
      model.table_name = 'first_models'
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
  end

  let(:second_model) do
    Class.new(ActiveRecord::Base) do |model|
      model.table_name = 'second_models'
      acts_as_removable column_name: :use_this_column
    end
  end

  let(:both_records) do
    [[first_model.create!, :removed_at], [second_model.create!, :use_this_column]]
  end

  it 'removable' do
    expect(first_model).to be_removable
    expect(first_model.new).to be_removable
  end

  it 'test column and check method' do
    both_records.each do |r, column_name|
      r.remove
      expect(r.removed?).to be(true)
      expect(r.send(column_name)).to be_kind_of(Time)
    end
  end

  describe 'scopes' do
    before do
      first_model.create!
      first_model.create!.remove!
      second_model.create!
      second_model.create!.remove!
    end

    it('finds present') { expect(first_model.present.count).to be(1) }
    it { expect(first_model.removed.count).to be(1) }
    it { expect(first_model.unscoped.count).to be(2) }
  end

  describe 'callbacks' do
    let(:record) { first_model.create! }

    context 'without call' do
      it do
        expect(record.callback_before_remove).to be(nil)
        expect(record.callback_after_remove).to be(nil)
        expect(record.callback_before_unremove).to be(nil)
        expect(record.callback_after_unremove).to be(nil)
      end
    end

    context 'with remove call' do
      before { record.remove }

      it do
        expect(record.callback_before_remove).to be(true)
        expect(record.callback_after_remove).to be(true)
        expect(record.callback_before_unremove).to be(nil)
        expect(record.callback_after_unremove).to be(nil)
      end
    end

    context 'with both calls' do
      before do
        record.remove
        record.unremove
      end

      it do
        expect(record.callback_before_remove).to be(true)
        expect(record.callback_after_remove).to be(true)
        expect(record.callback_before_unremove).to be(true)
        expect(record.callback_after_unremove).to be(true)
      end
    end
  end

  context 'with validate: true option' do
    let(:invalid_model) do
      Class.new(ActiveRecord::Base) do |model|
        model.table_name = 'invalids'

        def model.name
          'Invalid'
        end

        acts_as_removable validate: true
        validates :name, presence: true
      end
    end

    let(:invalid) { invalid_model.new.tap { |r| r.save(validate: false) } }

    it 'not remove' do
      expect(invalid.remove).to be(false)
      expect(invalid.reload.removed_at).to be(nil)
      expect(invalid.removed?).to be(false)
    end

    it 'raise error' do
      expect { invalid.remove! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(invalid.reload.removed_at).to be(nil)
      expect(invalid.removed?).to be(false)
    end
  end

  context 'with other models' do
    let(:other) do
      Class.new(ActiveRecord::Base) do |model|
        model.table_name = 'other_models'
      end
    end

    it 'not be removable' do
      expect(other).not_to be_removable
      expect(other.new).not_to be_removable
    end
  end
end
