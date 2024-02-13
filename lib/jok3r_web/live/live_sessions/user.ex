defmodule Jok3rWeb.LiveSessions.User do
  use Jok3rWeb, :live_view

  def on_mount(:default, _params, session, socket) do
    user_id = socket.user_id

    socket = socket |> assign(user_id: user_id)
    {:cont, socket}
  end
end
