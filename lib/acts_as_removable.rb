# frozen_string_literal: true

require 'active_support/concern'
require 'active_record'
require 'acts_as_removable/version'

module ActsAsRemovable
  extend ActiveSupport::Concern

  module ClassMethods
    #
    # call-seq:
    #   acts_as_removable
    #   acts_as_removable column_name: 'other_column_name', validate: true
    #
    # Add ability to remove ActiveRecord instances
    #
    # ==== Options
    #
    # [:column_name]
    #     \[+Symbol+ or +String+\]
    #
    #     A column name to use for removal timestamp.
    #
    #     <b>default:</b> 'removed_at'
    # [:validate]
    #     \[+true+ or +false+\]
    #
    #     Should record validations be performed with removal.
    #
    #     <b>default:</b> false
    def acts_as_removable(**options)
      @_acts_as_removable = true

      _acts_as_removable_options.merge!(options)

      scope :removed, lambda {
        where(all.table[_acts_as_removable_options[:column_name]].not_eq(nil).to_sql)
      }

      scope :present, lambda {
        where(all.table[_acts_as_removable_options[:column_name]].eq(nil).to_sql)
      }

      define_model_callbacks :remove, :unremove

      class_eval do
        def self.before_remove(*args, &block)
          set_callback(:remove, :before, *args, &block)
        end

        def self.after_remove(*args, &block)
          set_callback(:remove, :after, *args, &block)
        end

        def self.before_unremove(*args, &block)
          set_callback(:unremove, :before, *args, &block)
        end

        def self.after_unremove(*args, &block)
          set_callback(:unremove, :after, *args, &block)
        end

        def removed?
          send(self.class._acts_as_removable_options[:column_name]).present?
        end

        def remove(**options)
          _update_remove_attribute(Time.now, callback: :remove, with_bang: false, **options)
        end

        def remove!(**options)
          _update_remove_attribute(Time.now, callback: :remove, with_bang: true, **options)
        end

        def unremove(**options)
          _update_remove_attribute(nil, callback: :unremove, with_bang: false, **options)
        end

        def unremove!(**options)
          _update_remove_attribute(nil, callback: :unremove, with_bang: true, **options)
        end

        private

        def _default_remove_save_options # :nodoc:
          { validate: self.class._acts_as_removable_options[:validate] }
        end

        def _update_remove_attribute(value, callback:, with_bang: false, **options) # :nodoc:
          self.class.transaction do
            run_callbacks callback.to_sym do
              send("#{self.class._acts_as_removable_options[:column_name]}=", value)
              options = _default_remove_save_options.merge(options)
              with_bang ? save!(**options) : save(**options)
            end
          end
        end
      end
    end

    def removable?
      @_acts_as_removable || false
    end

    def _acts_as_removable_options # :nodoc:
      @_acts_as_removable_options ||= {
        column_name: 'removed_at',
        validate:    false
      }
    end
  end

  delegate :removable?, to: :class
end

ActiveRecord::Base.include(ActsAsRemovable)
