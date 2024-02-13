defmodule Jok3rWeb.MainLive.Index do
  use Jok3rWeb, :live_view

  alias Jok3r.Rooms.Admin

  def mount(_assigns, _session, socket) do
    form_fields = %{"topic" => "", "username" => ""}
    {:ok, assign(socket, form: to_form(form_fields))}
  end

  def handle_event("save", %{"topic" => topic, "username" => username} = params, socket) do
    case Admin.create_room(topic, username) do
      {:error, :room_already_exists} ->
        errors = [topic: {"Already exists", []}]

        {:noreply, assign(socket, form: to_form(params, errors: errors))}

      {:ok, room} ->
        room.manager_id

        socket =
          socket
          |> assign(user_id: room.manager_id)
          |> put_flash(:info, "Room created with success")
          |> push_navigate(to: "/room/#{room.id}")

        {:noreply, socket}
    end
  end
end
