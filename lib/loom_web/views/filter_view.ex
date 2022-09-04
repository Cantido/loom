defmodule LoomWeb.FilterView do
  use LoomWeb, :view

  def render("filter.json", %{filter: filter}) do
    if Enum.count(filter.properties) == 1 do
      %{filter.dialect => List.first(filter.properties)}
    else
      %{filter.dialect => render_many(filter, LoomWeb.FilterView, "filter.json")}
    end
  end
end
