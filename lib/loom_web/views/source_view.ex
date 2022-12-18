defmodule LoomWeb.SourceView do
  use LoomWeb, :view

  alias LoomWeb.SourceView

  def render("index.json", %{sources: sources}) do
    render_many(sources, SourceView, "source.json")
  end

  def render("show.json", %{source: source}) do
    render_one(source, SourceView, "source.json")
  end

  def render("source.json", %{source: source}) do
    %{name: source.source}
  end
end
