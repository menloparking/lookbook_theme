class ExamplePreview < Lookbook::Preview
  class Button
    def render_in(view_context)
      view_context.tag.button("Independent preview", id: "example-button")
    end
  end

  def alternate
    render Button.new
  end

  def default
    render Button.new
  end
end
