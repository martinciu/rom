module ROM
  module Commands
    class Graph
      # Class methods for command Graph
      #
      # @api private
      module ClassInterface
        # Build a command graph recursively
        #
        # This is used by `Env#command` when array with options is passed in
        #
        # @param [Registry] registry The command registry from env
        # @param [Array] options The options array
        # @param [Array] path The path for input evaluator proc
        #
        # @return [Graph]
        #
        # @api private
        def build(registry, options, path = EMPTY_ARRAY)
          options.reduce { |spec, other| build_command(registry, spec, other, path) }
        end

        # @api private
        def build_command(registry, spec, other, path)
          name, nodes = other

          key, relation =
            if spec.is_a?(Hash)
              spec.to_a.first
            else
              [spec, spec]
            end

          command = registry[relation][name]

          tuple_path = Array[*path] << key

          input_proc = -> *args do
            input, index = args

            begin
              if index
                tuple_path[0..tuple_path.size-2]
                  .reduce(input) { |a,e| a.fetch(e) }
                  .at(index)[tuple_path.last]
              else
                tuple_path.reduce(input) { |a,e| a.fetch(e) }
              end
            rescue KeyError => err
              raise CommandFailure.new(command, err)
            end
          end

          command = command.with(input_proc)

          if nodes
            if nodes.all? { |node| node.is_a?(Array) }
              command.combine(*nodes.map { |node| build(registry, node, tuple_path) })
            else
              command.combine(build(registry, nodes, tuple_path))
            end
          else
            command
          end
        end
      end
    end
  end
end
