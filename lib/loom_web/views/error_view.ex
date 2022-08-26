defmodule LoomWeb.ErrorView do
  use LoomWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  def template_not_found(template, _assigns) do
    msg = Phoenix.Controller.status_message_from_template(template)
    if String.ends_with?(template, ".json") do
      %{errors: [msg]}
    else
      msg
    end
  end
end
