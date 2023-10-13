defmodule Jok3rWeb.Header do
  use Jok3rWeb, :live_component

  def app_name, do: Application.spec(:jok3r, :description) || "DefaultAppName"
end
