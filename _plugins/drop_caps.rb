module Jekyll
  class IntroTag < Liquid::Block
    def initialize(tag_name, markup, tokens)
       super
       @rand = markup.to_i
    end

    def render(context)
      value = rand(@rand)
      super.sub('^^^', value.to_s)  # calling `super` returns the content of the block
    end
  end
end

Liquid::Template.register_tag('intro', Jekyll::IntroTag)
