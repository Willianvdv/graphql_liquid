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
      'fragment on User { name address { city country { iso } } }',
      'fragment on A { b { c { d { e { f { g } } } } } }',
      'fragment on Product { name price description }'
    ]
  end
end
