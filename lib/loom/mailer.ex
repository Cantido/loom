defmodule Loom.Mailer do
  @moduledoc """
  A `Swoosh.Mailer` module to send mail.
  """

  use Swoosh.Mailer, otp_app: :loom
end
