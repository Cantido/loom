defmodule LoomWeb.LayoutView do
  use LoomWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def alert(assigns) do
    if flash = get_flash(assigns.conn, assigns.type) do
      assigns = Map.put(assigns, :flash, flash)
      ~H"""
      <div uk-alert class={"uk-alert-#{@type}"} role="alert"><p><%= @flash %></p></div>
      """
    else
      ~H()
    end
  end
end
