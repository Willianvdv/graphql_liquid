require "spec_helper"

RSpec.describe GraphqlLiquid do
  let(:template) do
    %{
      <h1>Hi {{ user.name }} from {{ user.address.city }}, {{ user.address.country.iso }}</h1>
      {{ a.b.c.d.e.f.g }}
      <ul id="products">
        {% for product in products %}
          <li>
            <h2>{{ product.name }}</h2>
            Only {{ product.price | price }}

            {{ product.description | prettyprint | paragraph }}
          </li>
        {% endfor %}
     </ul>
    }
  end

  it 'returns the graphql fragments extracted from a liquid template' do
    expect(GraphqlLiquid::Parser.new(template).fragments).to eq({
      user: '... on User { name address { city country { iso } } }',
      a: '... on A { b { c { d { e { f { g } } } } } }',
      product: '... on Product { name price description }'
    })
  end

  describe 'hackery' do
    class GraphQLQueryExecutorViaHttp
      def execute(query)
        response = HTTParty.post(
          'https://hackerone.com/graphql', query:  { query: query }
        ).response.body

        data = JSON.parse(response)['data']
      end
    end

    def magic(template, root_query, executor)
      graphql_liquid = GraphqlLiquid::Parser.new template
      fragments = graphql_liquid.fragments
      query = root_query.call fragments
      data = executor.execute query
      graphql_liquid.liquid_template.render(data)
    end

    it 'hackerone user example' do
      root_query = lambda do |fragments|
        %{
          query {
            user(username: \"siebejan\") { #{fragments[:user]} }
            team(handle: \"security\") { #{fragments[:team]} }
          }
        }
      end

      executor = GraphQLQueryExecutorViaHttp.new
      # ^ the idea is that you can swap this with a local executor

      expect(
        magic \
          'Hello {{ user.name }} have you reported anything to {{ team.name }} today?',
          root_query,
          executor
      ).to eq 'Hello Siebe Jan Stoker have you reported anything to HackerOne today?'
    end
  end
end
