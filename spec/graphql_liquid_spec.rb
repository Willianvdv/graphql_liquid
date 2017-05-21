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
    expect(GraphqlLiquid::Parser.new(template).fragments).to eq [
      'fragment fragment_user on User { name address { city country { iso } } }',
      'fragment fragment_a on A { b { c { d { e { f { g } } } } } }',
      'fragment fragment_product on Product { name price description }'
    ]
  end

  describe 'hackery' do
    def magic(template, root_query)
      graphql_liquid = GraphqlLiquid::Parser.new template
      fragments = graphql_liquid.fragments

      user_fragment = fragments[0]
      root_query = "{ user(username: \"siebejan\") { ...fragment_user } } #{user_fragment}"

      response = HTTParty.post(
        'https://hackerone.com/graphql', query:  { query: root_query }
      ).response.body

      data = JSON.parse(response)['data']

      graphql_liquid.liquid_template.render(data)
    end

    it 'hackerone user example' do
      template = 'Hello {{ user.name }}'
      expect(magic(template, nil)).to eq 'Hello Siebe Jan Stoker'
    end
  end
end
