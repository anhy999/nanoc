# frozen_string_literal: true

require 'helper'

class Nanoc::Filters::TerserTest < Nanoc::TestCase
  def test_filter
    if_have 'terser' do
      # Create filter
      filter = ::Nanoc::Filter.named(:terser).new

      # Run filter
      input = 'foo = 1; (function(bar) { if (true) alert(bar); })(foo)'
      result = filter.setup_and_run(input)
      assert_match(/foo=1,function\((.)\)\{alert\(\1\)\}\(foo\);/, result)
    end
  end

  def test_filter_uglifyjs
    if_have 'terser' do
      # Create filter
      filter = ::Nanoc::Filter.named(:uglify_js).new

      # Run filter
      input = 'foo = 1; (function(bar) { if (true) alert(bar); })(foo)'
      result = filter.setup_and_run(input)
      assert_match(/foo=1,function\((.)\)\{alert\(\1\)\}\(foo\);/, result)
    end
  end

  def test_filter_with_options
    if_have 'terser' do
      filter = ::Nanoc::Filter.named(:terser).new

      input = "if(donkey) alert('It is a donkey!');"

      result = filter.setup_and_run(input, output: { beautify: false })
      assert_equal 'donkey&&alert("It is a donkey!");', result

      result = filter.setup_and_run(input, output: { beautify: true })
      assert_equal 'donkey && alert("It is a donkey!");', result
    end
  end
end
