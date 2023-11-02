defmodule Jok3r.Rooms.AdminTest do
  use ExUnit.Case, async: true
  alias Jok3r.Rooms.Admin

  setup do
    on_exit(fn ->
      :ets.delete_all_objects(:rooms)
    end)

    :ok
  end

  describe "create_room/2" do
    test "should create a room with a manager" do
      Admin.create_room("Test Topic", "Alice")

      [{"Test Topic", room}] = :ets.tab2list(:rooms)

      %{users: users, manager_id: manager_id} = room

      first_user = List.first(users)

      assert first_user.username == "Alice"
      assert manager_id == first_user.id
    end

    test "should get an error if the room already exists" do
      Admin.create_room("Test Topic", "Alice")

      assert {:error, :room_already_exists} == Admin.create_room("Test Topic", "Bob")
    end
  end

  describe "delete_room/2" do
    test "should delete a room when it exists and user is the manager" do
      Admin.create_room("Test Topic", "Alice")

      [{_topic, room}] = :ets.lookup(:rooms, "Test Topic")
      manager_id = room.manager_id

      assert :ok == Admin.delete_room("Test Topic", manager_id)
      assert :ets.lookup(:rooms, "Test Topic") == []
    end

    test "should return error when room exists but user is not the manager" do
      Admin.create_room("Test Topic", "Alice")

      bob_id = :crypto.hash(:sha256, "Bob#{:os.system_time(:millisecond)}") |> Base.encode16()

      assert {:error, :not_manager} == Admin.delete_room("Test Topic", bob_id)
    end

    test "should return error when trying to delete a non-existent room" do
      assert {:error, :room_not_found} == Admin.delete_room("Nonexistent Topic", "SomeID")
    end
  end

  describe "is_manager?/2" do
    test "should return true when user is the manager" do
      Admin.create_room("Test Topic", "Alice")

      [{_topic, room}] = :ets.lookup(:rooms, "Test Topic")
      manager_id = room.manager_id

      assert Admin.is_manager?("Test Topic", manager_id) == true
    end

    test "should return false when user is not the manager" do
      Admin.create_room("Test Topic", "Alice")

      bob_id = :crypto.hash(:sha256, "Bob#{:os.system_time(:millisecond)}") |> Base.encode16()

      assert Admin.is_manager?("Test Topic", bob_id) == false
    end

    test "should return error when room does not exist" do
      assert {:error, :room_not_found} == Admin.is_manager?("Nonexistent Topic", "SomeID")
    end
  end

  describe "change_room_state/3" do
    test "allows the room manager to change the room state" do
      Admin.create_room("poker", "manager")

      [{"poker", room}] = :ets.tab2list(:rooms)

      assert :ok = Admin.change_room_state("poker", room.manager_id, :active)
    end

    test "prevents non-managers from changing the room state" do
      Admin.create_room("poker", "manager")

      {:ok, user} = Admin.join_room("poker", "osw")

      assert {:error, :not_authorized} = Admin.change_room_state("poker", user.id, :active)
    end

    test "prevents changing the room state to an invalid value" do
      {:ok, room} = Admin.create_room("poker", "manager")

      assert_raise FunctionClauseError, fn ->
        Admin.change_room_state("poker", room.manager_id, :invalid_state)
      end
    end
  end

  describe "join_room/2" do
    test "adds a user to the room" do
      Admin.create_room("elixir", "josevalim")
      assert {:ok, _user} = Admin.join_room("elixir", "chrismccord")

      [{"elixir", room}] = :ets.tab2list(:rooms)

      assert Enum.any?(room.users, &(&1.username == "chrismccord"))
    end

    test "returns an error if the room does not exist" do
      assert {:error, :room_not_found} = Admin.join_room("unknown", "chrismccord")
    end

    test "returns an error if the user is already in the room" do
      Admin.create_room("elixir", "josevalim")
      Admin.join_room("elixir", "chrismccord")
      assert {:error, :user_already_in_room} = Admin.join_room("elixir", "chrismccord")
    end
  end

  describe "vote/3" do
    test "records the vote for a user in the room" do
      topic = "Functional Programming"
      username = "johndoe"
      {:ok, room} = Admin.create_room(topic, username)

      :ok = Admin.change_room_state(topic, room.manager_id, :active)

      vote_value = 1

      # Assuming that the manager is also added as a user in the room
      assert :ok = Admin.vote(topic, room.manager_id, vote_value)
    end

    test "returns :user_not_in_room if the user is not in the room" do
      topic = "Immutable Data"
      username = "janedoe"
      user_id = "some_user_id"
      vote_value = 1

      {:ok, room} = Admin.create_room(topic, username)
      :ok = Admin.change_room_state(topic, room.manager_id, :active)

      assert {:error, :user_not_in_room} = Admin.vote(topic, user_id, vote_value)
    end

    test "returns :room_not_found if the room does not exist" do
      topic = "Nonexistent Room"
      user_id = "user123"
      vote_value = 3

      assert {:error, :room_not_found} = Admin.vote(topic, user_id, vote_value)
    end

    test "returns :room_not_active if the room is not active" do
      topic = "Inactive Room"
      username = "inactiveuser"
      vote_value = 2

      {:ok, room} = Admin.create_room(topic, username)

      # No activation of the room, it remains inactive
      assert {:error, :room_not_active} = Admin.vote(topic, room.manager_id, vote_value)
    end
  end

  describe "get_room_status/1" do
    test "returns the current state of an existing room" do
      {:ok, room} = Admin.create_room("room_topic", "manager_username")
      Admin.change_room_state("room_topic", room.manager_id, :active)

      assert {:ok, :active} == Admin.get_room_status("room_topic")
    end

    test "returns an error if the room does not exist" do
      assert {:error, :room_not_found} ==
               Admin.get_room_status("non_existing_room_topic")
    end
  end

  describe "get_room_data/1" do
    test "returns the data for an existing room" do
      {:ok, room} = Admin.create_room("room_topic", "manager_username")

      {:ok, room_2} = Admin.get_room_data("room_topic")

      assert room_2.manager_id == room.manager_id
    end

    test "returns an error if the room does not exist" do
      assert {:error, :room_not_found} ==
               Admin.get_room_data("non_existing_room_topic")
    end
  end

  describe "restart_room/2" do
    test "restarts the room only if the manager calls it" do
      {:ok, room} = Admin.create_room("room_topic", "manager_username")
      Admin.join_room("user1", "room_topic")

      assert {:error, :unauthorized} =
               Admin.restart_room("room_topic", "wrong_manager_id")

      assert :ok = Admin.restart_room("room_topic", room.manager_id)
    end
  end
end
