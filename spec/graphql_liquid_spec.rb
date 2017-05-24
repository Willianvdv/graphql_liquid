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
    def magic(template, root_query)
      graphql_liquid = GraphqlLiquid::Parser.new template
      fragments = graphql_liquid.fragments

      query = root_query.call fragments

      response = HTTParty.post(
        'https://hackerone.com/graphql', query:  { query: query }
      ).response.body

      data = JSON.parse(response)['data']

      # TODO: Do something with the errors!

      graphql_liquid.liquid_template.render(data)
    end

    it 'hackerone user example' do
      root_query = lambda do |fragments|
        "query { user(username: \"siebejan\") { #{fragments[:user] } } }"
      end

      expect(
        magic('Hello {{ user.name }}', root_query)
      ).to eq 'Hello Siebe Jan Stoker'
    end
  end
end
