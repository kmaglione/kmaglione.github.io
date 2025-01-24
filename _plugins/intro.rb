module Jekyll
  class IntroTag < Liquid::Block
    def initialize(tag_name, markup, tokens)
       super
    end

    def render(context)
      text = super.strip
      "<p class=\"intro\" markdown=\"1\"><span class=\"dropcap\">#{text[0]}</span>#{text[1..text.length]}</p>"
    end
  end
end

Liquid::Template.register_tag('intro', Jekyll::IntroTag)
