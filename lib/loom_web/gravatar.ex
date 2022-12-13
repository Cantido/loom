defmodule LoomWeb.Gravatar do
  def user_gravatar_url(user) do
    email =
      String.trim(user.email)
      |> String.downcase()

    hash = :crypto.hash(:md5, email) |> Base.encode16(case: :lower)

    "https://gravatar.com/avatar/#{hash}?d=identicon"
  end
end
