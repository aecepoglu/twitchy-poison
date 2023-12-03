defmodule IRC.RoomRegistryTest do
  use ExUnit.Case

  test "..." do
    id1 = {"chan1", "room1"}
    id2 = {"chan1", "room2"}
    id3 = {"chan2", "room1"}
    id4 = {"chan2", "room2"}

    [id1, id2, id3, id4]
    |> Enum.each(&IRC.create_room/1)

    addr = 

    :ok = IRC.Room.add_user(IRC.via(id1), "usr1")
    :ok = IRC.Room.add_user(IRC.via(id1), "usr2")
    :ok = IRC.Room.add_user(IRC.via(id3), "usr1")

    users = [id1, id2, id3, id4]
    |> Enum.map(fn id -> id |> IRC.via |> IRC.Room.users |> Map.keys end)

    assert users == [
      ["usr1", "usr2"],
      [],
      ["usr1"],
      []
    ]
  end
end

defmodule IRC.RoomTest do
  import IRC.Room
  use ExUnit.Case

  @tag :wip
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

  @tag :wip
  test "if all messages are old, render from latest to fill the screen" do
    {lines, unread} = %IRC.Room{ id: "room 123" }
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
    assert unread == 0
  end

  @tag :wip
  test "Add colour to usernames, tracking colour across multiple lines" do
    {lines, _unread} = %IRC.Room{id: "room 123"}
    |> record_chat({"userr12345678901234", "six four", color: "{COLOR1}"})
    |> record_chat({"user", "six four", color: "{COLOR1}"})
    |> record_chat({"user", "two", color: "{COLOR2}"})
    |> Map.put(:unread, 0)
    |> render_and_count({15, 5}, indent: "", skip_unread: false)
    expected = """
 : -
 {COLOR1}userr123456789#{IO.ANSI.default_color}
 {COLOR1}01234#{IO.ANSI.default_color}: six four
 {COLOR1}user#{IO.ANSI.default_color}: six four
 {COLOR2}user#{IO.ANSI.default_color}: two
""" |> String.trim_trailing |> String.split("\n")
    assert lines == expected
  end

  @tag :wip
  test "skip_unread ignores unread messages, rendering the last batch of read msgs" do
    {lines, unread} = %IRC.Room{id: "room 123"}
    |> record_chat({"user", "zero"})
    |> record_chat({"user", "one"})
    |> record_chat({"user", "two"})
    |> record_chat({"user", "three"})
    |> record_chat({"user", "four"})
    |> record_chat({"user", "five"})
    |> record_chat({"user", "six"}) # new
    |> record_chat({"user", "seven eight nine"}) # new
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

  @tag :skip
  test "screen is empty if it's too small to fit a single message" do
    {lines, unread} = %IRC.Room{ id: "room 123" }
    |> record_chat({"user", "one two three four five six seven eight nine ten eleven twelve"})
    |> Map.put(:unread, 1)
    |> render_and_count({10, 5}, indent: "... ")
    assert lines == []
    assert unread == 0
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

  test "render_and_read() to progress through unread messages" do
    {lines, unread} =
      %IRC.Room{ id: "room 123" }
      |> record_chat({"user", "1"})
      |> record_chat({"user", "2"})
      |> record_chat({"user", "3"})
      |> record_chat({"user", "4"})
      |> record_chat({"user", "5"})
      |> record_chat({"user", "6"})
      |> record_chat({"user", "7"})
      |> record_chat({"user", "8"})
      |> record_chat({"user", "9"})
      |> record_chat({"user", "10"})
      |> render_and_count({20, 4}, skip_unread: false)

    assert lines == [
      "+user: 1",
      "+user: 2",
      "+user: 3",
      "+user: 4",
    ]
    assert unread == 6
  end
end
