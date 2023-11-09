defmodule TodoTest do
  use ExUnit.Case
  import Todo

  test "add next adds before the only done item" do
    lines = empty()
    |> add(%Todo{label: "1"}, :push)
    |> mark_done!
    |> add(%Todo{label: "2"}, :next)
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ 2",
      "  ✔ 1",
    ]
  end

  test "add" do
    lines = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> del
    |> add(%Todo{label: "3"}, :push)
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ 3",
      "  ⋅ 1"
    ]
  end

  test "rot" do
    lines = empty()
    |> add(%Todo{label: "1", done: true}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> add(%Todo{label: "3"}, :push)
    |> rot(:outside)
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ 2",
      "  ⋅ 3",
      "  ✔ 1",
    ]
  end

  test "rot outside over a group" do
    todos = [
      %Todo{label: "1"},
      [ %Todo{label: "2"},
        %Todo{label: "3"},
        %Todo{label: "4"},
      ],
      %Todo{label: "5"},
    ]
    |> rot(:outside)

    assert todos == [
      [ %Todo{label: "2"},
        %Todo{label: "3"},
        %Todo{label: "4"},
      ],
      %Todo{label: "5"},
      %Todo{label: "1"},
    ]
  end

  test "pop one out of a group" do
    lines = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> add(%Todo{label: "3"}, :push)
    |> join_eager
    |> pop
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ 3",
      "╭ ⋅ 2",
      "╰ ⋅ 1",
    ]
  end

  test "pop out a pair" do
    lines = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> join
    |> pop
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ 2",
      "  ⋅ 1",
    ]
  end

  test "del lonely item" do
    lines = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> add(%Todo{label: "3"}, :push)
    |> del
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ 2",
      "  ⋅ 1",
    ]
  end

  test "del out of a group" do
    lines = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> add(%Todo{label: "3"}, :push)
    |> join_eager()
    |> del
    |> strings(40, color: false)

    assert lines == [
      "╭ ⋅ 2",
      "╰ ⋅ 1",
    ]
  end

  test "del disbands group of 1" do
    lines = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> join_eager()
    |> add(%Todo{label: "3"}, :push)
    |> pop
    |> add(%Todo{label: "4"}, :push)
    |> del
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ 3",
      "╭ ⋅ 2",
      "╰ ⋅ 1",
    ]
  end

  test "string of one" do
    lines =  [
      [%Todo{label: "1"}]
    ]
    |> strings(40, color: false)

    assert lines == [
      "< ⋅ 1"
    ]
  end

  test "long lines fold" do
    lines = empty()
    |> add(%Todo{label: "hii"}, :push)
    |> add(%Todo{label: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen"}, :push)
    |> add(%Todo{label: "bye"}, :push)
    |> join
    |> add(%Todo{label: "ungrouped"}, :push)
    |> pop()
    |> strings(40, color: false)

    assert lines == [
      "  ⋅ ungrouped",
      "╭ ⋅ bye",
      "│ ⋅ one two three four five six seven",
      "│   eight nine ten eleven twelve",
      "│   thirteen fourteen fifteen sixteen",
      "╰   seventeen",
      "  ⋅ hii",
    ]
  end

  test "mark_done" do
    lines = empty()
    |> add(%Todo{label: "one"}, :push)
    |> add(%Todo{label: "two"}, :push)
    |> add(%Todo{label: "three"}, :push)
    |> join
    |> mark_done!

    assert lines == [
      [ %Todo{             label: "two"},
        %Todo{done: true, label: "three"},
      ],
      %Todo{             label: "one"},
    ]
  end

  test "join eagerly" do
    lines = empty()
    |> add(%Todo{label: "one"}, :push)
    |> add(%Todo{label: "two"}, :push)
    |> add(%Todo{label: "three"}, :push)
    |> join
    |> join
    |> add(%Todo{label: "four"}, :push)
    |> pop()
    |> add(%Todo{label: "five"}, :push)
    |> add(%Todo{label: "six"}, :push)
    |> join_eager
    |> add(%Todo{label: "seven"}, :push)
    |> pop()
    |> add(%Todo{label: "eight"}, :push)
    |> add(%Todo{label: "nine"}, :push)
    |> join_eager
    |> strings(40)

    assert lines == [
      "╭ ⋅ nine",
      "│ ⋅ eight",
      "╰ ⋅ seven",
      "╭ ⋅ six",
      "│ ⋅ five",
      "╰ ⋅ four",
      "╭ ⋅ three",
      "│ ⋅ two",
      "╰ ⋅ one",
    ]
  end

  test "mark_done rotates tasks" do
    t1 = %Todo{label: "one"}
    t2 = %Todo{label: "two"}
    t3 = %Todo{label: "three", done: true}

    assert mark_done!([t1, t2, t3]) == [t2, t3, %{t1 | done: true}]
  end

  test "renders only as many lines as fits on screen" do
    lines = [
      %Todo{label: "1"},
      %Todo{label: "2"},
      %Todo{label: "3"},
      %Todo{label: "4000 4111 4222"},
      %Todo{label: "5"},
      %Todo{label: "6"},
    ]
    |> render({9, 5})
    |> elem(1)
    |> String.split("\n\r")

    assert lines == [
      "  ⋅ 1",
      "  ⋅ 2",
      "  ⋅ 3",
      "  ⋅ 4000",
      "    4111",
    ]
    |> Enum.map(& "\e[2K" <> &1)
  end
end

defmodule TodoParserTest do
  use ExUnit.Case
  import Todo.Parser, only: [parse: 2]

  test "strings go as is and bullets are ignored" do
    assert parse("x what is this?", has_todobqn: true) == %{
      label: "x what is this?",
    }
  end

  test "todobqn task ID is parsed out of tsv" do
    assert parse("194\tx who what when here", has_todobqn: true) == %{
      label: "x who what when here",
      hooks: [todobqn: "194"],
      done: false,
    }
  end
end
