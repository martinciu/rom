require 'rom/pipeline'
require 'rom/mapper_registry'

require 'rom/relation/loaded'
require 'rom/relation/composite'
require 'rom/relation/graph'
require 'rom/relation/materializable'

module ROM
  class Relation
    # Lazy relation wraps canonical relation for data-pipelining
    #
    # @example
    #   ROM.setup(:memory)
    #
    #   class Users < ROM::Relation[:memory]
    #     def by_name(name)
    #       restrict(name: name)
    #     end
    #   end
    #
    #   rom = ROM.finalize.env
    #
    #   rom.relations.users << { name: 'Jane' }
    #   rom.relations.users << { name: 'Joe' }
    #
    #   mapper = proc { |users| users.map { |user| user[:name] } }
    #   users = rom.relation(:users)
    #
    #   (users.by_name >> mapper)['Jane'].inspect # => ["Jane"]
    #
    # @api public
    class Lazy
      include Equalizer.new(:relation, :options)
      include Options
      include Materializable
      include Pipeline

      option :mappers, reader: true, default: proc { MapperRegistry.new }

      # @return [Relation]
      #
      # @api private
      attr_reader :relation

      # Map of exposed relation methods
      #
      # @return [Hash<Symbol=>TrueClass>]
      #
      # @api private
      attr_reader :exposed_relations

      # @api private
      def initialize(relation, options = {})
        super
        @relation = relation
        @exposed_relations = @relation.exposed_relations
      end

      # Eager load other relation(s) for this relation
      #
      # @param [Array<Relation>] others The other relation(s) to eager load
      #
      # @return [Relation::Graph]
      #
      # @api public
      def combine(*others)
        Graph.build(self, others)
      end

      # Build a relation pipeline using registered mappers
      #
      # @example
      #   rom.relation(:users).map_with(:json_serializer)
      #
      # @return [Relation::Composite]
      #
      # @api public
      def map_with(*names)
        [self, *names.map { |name| mappers[name] }]
          .reduce { |a, e| Composite.new(a, e) }
      end
      alias_method :as, :map_with

      # Load relation
      #
      # @return [Relation::Loaded]
      #
      # @api public
      def call
        Loaded.new(relation)
      end

      # @api private
      def respond_to_missing?(name, include_private = false)
        exposed_relations.include?(name) || super
      end

      # Return if this lazy relation is curried
      #
      # @return [false]
      #
      # @api private
      def curried?
        false
      end

      private

      # Forward methods to the underlaying relation
      #
      # Auto-curry relations when args size doesn't match arity
      #
      # @return [Lazy,Curried]
      #
      # @api private
      def method_missing(meth, *args, &block)
        if !exposed_relations.include?(meth) || (curried? && name != meth)
          super
        else
          arity = relation.method(meth).arity

          if arity < 0 || arity == args.size
            response = relation.__send__(meth, *args, &block)

            if response.is_a?(Relation)
              __new__(response)
            else
              response
            end
          else
            Curried.new(relation, name: meth, curry_args: args, arity: arity)
          end
        end
      end

      # Return new lazy relation with updated options
      #
      # @api private
      def __new__(relation, new_opts = {})
        Lazy.new(relation, options.merge(new_opts))
      end
    end
  end
end
