defmodule IRC.RoomTest do
  import IRC.Room
  use ExUnit.Case

  test "render the chat" do
    {lines, unread} = %IRC.Room{ id: "room 123" }
    |> record_chat({"user1", "hello"})
    |> record_chat({"user2", "hi"})
    |> record_chat({"user1", "hi to you too good man"})
    |> record_chat({"user2", "who said I'm a guy. Don't be sexist"})
    |> record_chat({"user1", "Must we do this right now? This is just data for testing :/"})
    |> Map.put(:unread, 2)
    |> render_and_count({20, 15}, indent: "... ")
    expected = """
 : -
 : -
 : -
 user1: hello
 user2: hi
 user1: hi to you
 ... too good man
+user2: who said I'm
+... a guy. Don't be
+... sexist
+user1: Must we do
+... this right now?
+... This is just
+... data for
+... testing :/
""" |> String.trim_trailing |> String.split("\n")
    assert lines == expected
    assert unread == 0
  end

  test "only render as many messages as fits in the screen" do
    {lines, _} = %IRC.Room{ id: "room 123" }
    |> record_chat({"user", "one"})
    |> record_chat({"user", "two"})
    |> record_chat({"user", "three"})
    |> record_chat({"user", "four"})
    |> record_chat({"user", "five"})
    |> record_chat({"user", "six"})
    |> record_chat({"user", "seven eight nine"})
    |> Map.put(:unread, 0)
    |> render_and_count({10, 5}, indent: "....")
    expected = """
 user: six
 user:
 ....seven
 ....eight
 ....nine
""" |> String.trim_trailing |> String.split("\n")
    assert lines == expected
  end

  test "render only the old messages" do
    {lines, unread} = %IRC.Room{id: "room 123"}
    |> record_chat({"user", "one"})
    |> record_chat({"user", "two"})
    |> record_chat({"user", "three"})
    |> record_chat({"user", "four"})
    |> record_chat({"user", "five"})
    |> record_chat({"user", "six"})
    |> record_chat({"user", "seven eight nine"})
    |> Map.put(:unread, 2)
    |> render_and_count({15, 5}, indent: "....", skip_unread: true)
    expected = """
 user: one
 user: two
 user: three
 user: four
 user: five
""" |> String.trim_trailing |> String.split("\n")
    assert lines == expected
    assert unread == 2
  end

  test "screen is empty if it's too small to fit a single message" do
    {lines, _} = %IRC.Room{ id: "room 123" }
    |> record_chat({"user", "one two three four five six seven eight nine ten eleven twelve"})
    |> Map.put(:unread, 1)
    |> render_and_count({10, 5}, indent: "... ")
    assert lines == []
  end

  test "list all messages by a user" do
    msgs = %IRC.Room{ id: "room 123" }
    |> record_chat({"user1", "one"})
    |> record_chat({"user2", "two"})
    |> record_chat({"user1", "three"})
    |> record_chat({"user2", "four"})
    |> record_chat({"user3", "five"})
    |> record_chat({"user1", "six"})
    |> record_chat({"user1", "seven"})
    |> log_user("user1")

    assert msgs == ["seven", "six", "three", "one"]
  end

  test "receive empty list when attempting to list messages of nonexistent user" do
    msgs = %IRC.Room{ id: "room 123" }
    |> record_chat({"user1", "one"})
    |> record_chat({"user2", "two"})
    |> log_user("user3")

    assert msgs == []
  end

  test "listing messages have a history limit" do
    room = %IRC.Room{ id: "room 123" }
    |> record_chat({"old_user", "one"})
    room_ = Enum.reduce(
      1..(room.chat.size + 1),
      room,
      fn _, room1 -> record_chat(room1, {"new_user", "msg"}) end)
    assert log_user(room_, "old_user") |> length == 0
    assert log_user(room_, "new_user") |> length == room.chat.size
  end
end
