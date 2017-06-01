require 'spec_helper'

RSpec.describe GraphqlLiquid do
  it 'returns the graphql fragments extracted from a liquid template' do
    template = \
      %(
        <h1>
          Hi {{ user.name }} from {{ user.address.city }},
          {{ user.address.country.iso }}
        </h1>

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
      )

    expect(GraphqlLiquid::Parser.new(template).fragments).to eq(
      user: '... on User { name address { city country { iso } } }',
      a: '... on A { b { c { d { e { f { g } } } } } }',
      product: '... on Product { name price description }'
    )
  end

  describe 'render a template using data from graphql endpoints' do
    it 'hackerone user example' do
      class HackerOneGraphQL
        def execute(query)
          response = HTTParty.post(
            'https://hackerone.com/graphql', query: { query: query }
          ).response.body

          JSON.parse(response)['data']
        end
      end

      root_query = lambda do |fragments|
        %{
          query {
            user(username: \"siebejan\") { #{fragments[:user]} }
            team(handle: \"security\") { #{fragments[:team]} }
          }
        }
      end

      renderer = GraphqlLiquid::Renderer.new \
        'Hello {{ user.name }} have you reported anything to {{ team.name }} today?',
        root_query,
        HackerOneGraphQL.new

      expect(renderer.render).to eq \
        'Hello Siebe Jan Stoker have you reported anything to HackerOne today?'
    end
  end
end
