defmodule Loom.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en"],
    providers: [
      Cldr.Calendar,
      Cldr.DateTime,
      Cldr.Number,
      Cldr.Unit
    ]
end
