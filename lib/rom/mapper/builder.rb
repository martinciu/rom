# encoding: utf-8

module ROM
  class Mapper

    # Builder DSL for ROM mappers
    #
    class Builder
      include Adamantium::Flat

      attr_reader :environment, :schema, :model
      private :environment, :schema, :model

      # Initialize a new mapping instance
      #
      # @return [undefined]
      #
      # @api private
      def initialize(environment, schema, &block)
        @environment = environment
        @schema      = schema
        instance_eval(&block)
      end

      private

      # Method missing hook
      #
      # @return [Relation]
      #
      # @api private
      def method_missing(name, *, &block)
        relation = schema[name]

        if relation
          build_relation(name, relation, &block)
        else
          super
        end
      end

      # Build relation
      #
      # @return [Relation]
      #
      # @api private
      def build_relation(name, relation, &block)
        definition = Mapper::DSL::Definition.build(relation.header, &block)
        environment[name] = Relation.new(relation, definition.mapper)
      end

    end # Builder

  end # Mapper
end # ROM
