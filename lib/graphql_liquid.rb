require 'graphql_liquid/version'
require 'liquid'
require 'httparty'

module GraphqlLiquid
  class Renderer
    def initialize(template, root_query, executor)
      @template = template
      @root_query = root_query
      @executor = executor
      @parsed = Parser.new template
    end

    def render
      query = root_query.call parsed.fragments
      template_data = executor.execute query
      parsed.liquid_template.render template_data
    end

    private

    attr_reader :parsed, :template, :root_query, :executor
  end

  class Parser
    def initialize(template)
      @template = template
      @liquid_template = Liquid::Template.parse(template)
    end

    def fragments
      tags = []

      liquid_template.root.nodelist.map do |node|
        tags << node if node.class == Liquid::Variable

        next unless node.respond_to?(:nodelist)
        node.nodelist.inject(tags) do |new_tags, child_node|
          new_tags << child_node.nodelist.reject do |grandchild|
            grandchild.is_a? String
          end
        end
      end

      tags.flatten!

      fragments = {}
      tags.each do |tag|
        new_graphql_nodes = GraphQLThing.new tag.name.lookups

        nodes = if (existing_graphql_nodes = fragments[tag.name.name])
                  merge_existing_nodes_with_new_nodes \
                    existing_graphql_nodes, new_graphql_nodes
                else
                  [new_graphql_nodes]
                end

        fragments[tag.name.name] = nodes
      end

      fragments.map do |k, v|
        [k.to_sym, "... on #{k.capitalize} { #{v.map(&:to_graphql).join(' ')} }"]
      end.to_h
    end

    attr_reader :template, :liquid_template

    private

    def merge_existing_nodes_with_new_nodes(existing_nodes, new_nodes)
      if (existing_node_with_the_same_name = existing_nodes.find { |nodes| nodes.attribute_name == new_nodes.attribute_name })
        existing_node_with_the_same_name.merge_with new_nodes
        existing_nodes
      else
        existing_nodes + [new_nodes]
      end
    end

    class GraphQLThing
      attr_reader :attribute_name, :children

      def initialize((attribute_name, *children))
        @attribute_name = attribute_name
        @children = children || []
      end

      def merge_with(other_thing)
        @children += [other_thing.children]

        self
      end

      def to_graphql
        attributes_to_graphql([attribute_name] + children)
      end

      private

      def attributes_to_graphql(attributes)
        attribute_name, *children = attributes
        if children.size == 1 && children[0].is_a?(Array)
          "#{attribute_name} #{attributes_to_graphql children[0]}"
        elsif !children.empty?
          "#{attribute_name} { #{attributes_to_graphql children} }"
        else
          attribute_name
        end
      end
    end
  end
end
