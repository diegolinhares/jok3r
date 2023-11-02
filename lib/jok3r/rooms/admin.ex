defmodule Jok3r.Rooms.Admin do
  use GenServer

  alias Jok3r.{Room, User}

  @valid_states [:waiting, :active, :reveal]

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    rooms =
      :ets.new(:rooms, [
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{rooms: rooms}}
  end

  def create_room(topic, username) do
    GenServer.call(__MODULE__, {:create_room, topic, username})
  end

  def delete_room(topic, manager_id) do
    GenServer.call(__MODULE__, {:delete_room, topic, manager_id})
  end

  def is_manager?(topic, user_id) do
    GenServer.call(__MODULE__, {:is_manager, topic, user_id})
  end

  def join_room(topic, username) do
    GenServer.call(__MODULE__, {:join_room, topic, username})
  end

  def change_room_state(topic, manager_id, new_state) when new_state in @valid_states do
    GenServer.call(__MODULE__, {:change_room_state, topic, manager_id, new_state})
  end

  def vote(topic, user_id, vote_value) do
    GenServer.call(__MODULE__, {:vote, topic, user_id, vote_value})
  end

  def get_room_status(topic) do
    GenServer.call(__MODULE__, {:get_room_status, topic})
  end

  def get_room_data(topic) do
    GenServer.call(__MODULE__, {:get_room_data, topic})
  end

  def restart_room(topic, manager_id) do
    GenServer.call(__MODULE__, {:restart_room, topic, manager_id})
  end

  def handle_call({:create_room, topic, username}, _from, %{rooms: rooms} = state) do
    if room_exists?(topic) do
      {:reply, {:error, :room_already_exists}, state}
    else
      manager = generate_user(username)
      room = generate_room(manager)
      :ets.insert(rooms, {topic, room})
      {:reply, {:ok, room}, state}
    end
  end

  def handle_call({:delete_room, topic, manager_id}, _from, %{rooms: rooms} = state) do
    case :ets.lookup(rooms, topic) do
      [] ->
        {:reply, {:error, :room_not_found}, state}

      [{_topic, %Room{manager_id: ^manager_id}}] ->
        :ets.delete(rooms, topic)
        {:reply, :ok, state}

      _ ->
        {:reply, {:error, :not_manager}, state}
    end
  end

  def handle_call({:is_manager, topic, user_id}, _from, %{rooms: rooms} = state) do
    case :ets.lookup(rooms, topic) do
      [] ->
        {:reply, {:error, :room_not_found}, state}

      [{_topic, %Room{manager_id: ^user_id}}] ->
        {:reply, true, state}

      _ ->
        {:reply, false, state}
    end
  end

  def handle_call({:join_room, topic, username}, _from, %{rooms: rooms} = state) do
    case :ets.lookup(:rooms, topic) do
      [] ->
        {:reply, {:error, :room_not_found}, state}

      [{_topic, room}] ->
        if Enum.any?(room.users, &(&1.username == username)) do
          {:reply, {:error, :user_already_in_room}, state}
        else
          user = %User{id: generate_user_id(username), username: username}
          updated_users = [user | room.users]
          updated_room = %{room | users: updated_users}
          :ets.insert(rooms, {topic, updated_room})
          {:reply, {:ok, user}, state}
        end
    end
  end

  def handle_call(
        {:change_room_state, topic, manager_id, new_state},
        _from,
        %{rooms: rooms} = state
      ) do
    case :ets.lookup(rooms, topic) do
      [] ->
        {:reply, {:error, :room_not_found}, state}

      [{_topic, %Room{manager_id: ^manager_id} = room}] ->
        updated_room = %{room | state: new_state}
        :ets.insert(rooms, {topic, updated_room})
        {:reply, :ok, state}

      _ ->
        {:reply, {:error, :not_authorized}, state}
    end
  end

  def handle_call({:vote, topic, user_id, vote_value}, _from, %{rooms: rooms} = state) do
    case :ets.lookup(rooms, topic) do
      [{_topic, %Room{state: :active, users: users} = room}] ->
        if user_in_room?(users, user_id) do
          updated_room = update_user_vote(room, user_id, vote_value)
          :ets.insert(rooms, {topic, updated_room})
          {:reply, :ok, state}
        else
          {:reply, {:error, :user_not_in_room}, state}
        end

      [] ->
        {:reply, {:error, :room_not_found}, state}

      [_] ->
        {:reply, {:error, :room_not_active}, state}
    end
  end

  defp update_user_vote(%Room{users: users} = room, user_id, vote_value) do
    updated_users =
      Enum.map(users, fn user ->
        if user.id == user_id, do: %{user | card: vote_value}, else: user
      end)

    %{room | users: updated_users}
  end

  defp user_in_room?(users, user_id) do
    Enum.any?(users, &(&1.id == user_id))
  end

  def handle_call({:get_room_status, topic}, _from, %{rooms: rooms} = state) do
    case :ets.lookup(rooms, topic) do
      [] ->
        {:reply, {:error, :room_not_found}, state}

      [{_topic, %Room{state: room_state}}] ->
        {:reply, {:ok, room_state}, state}
    end
  end

  def handle_call({:get_room_data, topic}, _from, %{rooms: rooms} = state) do
    case :ets.lookup(rooms, topic) do
      [] ->
        {:reply, {:error, :room_not_found}, state}

      [{_topic, room_data}] ->
        {:reply, {:ok, room_data}, state}
    end
  end

  def handle_call({:restart_room, topic, manager_id}, _from, state) do
    case :ets.lookup(:rooms, topic) do
      [{_topic, room}] ->
        if room.manager_id == manager_id do
          new_room = %{room | state: :active, users: clear_cards(room.users)}

          :ets.insert(:rooms, {topic, new_room})

          {:reply, :ok, state}
        else
          {:reply, {:error, :unauthorized}, state}
        end

      [] ->
        {:reply, {:error, :room_not_found}, state}
    end
  end

  defp clear_cards(users) do
    Enum.map(users, fn user -> Map.put(user, :card, nil) end)
  end

  defp room_exists?(topic) do
    :ets.lookup(:rooms, topic) != []
  end

  defp generate_user(username) do
    user_id = generate_user_id(username)

    %User{
      id: user_id,
      username: username,
      card: nil
    }
  end

  defp generate_user_id(username) do
    :crypto.hash(:sha256, "#{username}#{:os.system_time(:millisecond)}")
    |> Base.encode16()
  end

  defp generate_room(manager) do
    %Room{
      users: [manager],
      manager_id: manager.id
    }
  end
end
