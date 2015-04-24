module ActiveAdmin
  module Mongoid
    module Document
      extend ActiveSupport::Concern

      included do        
      end

      module ClassMethods

        def content_columns
          fields.map(&:second).reject do |f|
            f.name =~ /^_/ || ::Mongoid::Fields::ForeignKey === f
          end
        end

      end
    end # Document
  end
end

Mongoid::Document.send :include, ActiveAdmin::Mongoid::Document
