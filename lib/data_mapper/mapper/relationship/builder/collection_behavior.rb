module DataMapper
  class Mapper
    class Relationship
      class Builder

        module CollectionBehavior

          def target_model_attribute_options
            super.merge(:collection => true)
          end
        end # module CollectionBehavior
      end # class Builder
    end # class Relationship
  end # class Mapper
end # module DataMapper
