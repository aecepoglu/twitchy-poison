defmodule TodoTest do
  use ExUnit.Case
  import Todo
  test "string" do
    right = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> del
    |> add(%Todo{label: "3"}, :push)
    |> strings(40, color: false)

    left = [
      "  ○ 3",
      "  ○ 1"
    ]

    assert left == right
  end

  test "pop one out of a group" do
    received = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> add(%Todo{label: "3"}, :push)
    |> join_eager
    |> pop
    |> strings(40, color: false)
    assert received == [
      "  ○ 3",
      "╭ ○ 2",
      "╰ ○ 1",
    ]
  end

  test "pop out a pair" do
    received = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> join
    |> pop
    |> strings(40, color: false)
    assert received == [
      "  ○ 2",
      "  ○ 1",
    ]
  end

  test "del lonely item" do
    received = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> add(%Todo{label: "3"}, :push)
    |> del
    |> strings(40, color: false)
    assert received == [
      "  ○ 2",
      "  ○ 1",
    ]
  end

  test "del out of a group" do
    received = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> add(%Todo{label: "3"}, :push)
    |> join_eager()
    |> del
    |> strings(40, color: false)
    assert received == [
      "╭ ○ 2",
      "╰ ○ 1",
    ]
  end

  test "del disbands group of 1" do
    received = empty()
    |> add(%Todo{label: "1"}, :push)
    |> add(%Todo{label: "2"}, :push)
    |> join_eager()
    |> add(%Todo{label: "3"}, :push)
    |> pop
    |> add(%Todo{label: "4"}, :push)
    |> del
    |> strings(40, color: false)
    assert received == [
      "  ○ 3",
      "╭ ○ 2",
      "╰ ○ 1",
    ]
  end

  test "string of one" do
    strings =  [
      [%Todo{label: "1"}]
    ]
    |> strings(40, color: false)

    assert strings == [
      "< ○ 1"
    ]
  end

  test "long lines fold" do
    right = empty()
    |> add(%Todo{label: "hii"}, :push)
    |> add(%Todo{label: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen"}, :push)
    |> add(%Todo{label: "bye"}, :push)
    |> join
    |> add(%Todo{label: "ungrouped"}, :push)
    |> pop()
    |> strings(40, color: false)

    left = [
      "  ○ ungrouped",
      "╭ ○ bye",
      "│ ○ one two three four five six seven ei",
      "│   ght nine ten eleven twelve thirteen ",
      "╰   fourteen fifteen sixteen seventeen",
      "  ○ hii",
    ]
    assert left == right
  end

  test "mark_done" do
    right = empty()
    |> add(%Todo{label: "one"}, :push)
    |> add(%Todo{label: "two"}, :push)
    |> add(%Todo{label: "three"}, :push)
    |> join
    |> mark_done!

    expected = [
      [ %Todo{             label: "two"},
        %Todo{done?: true, label: "three"},
      ],
      %Todo{             label: "one"},
    ]
    assert right == expected
  end

  test "join eagerly" do
    created = empty()
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

    expected = [
      "╭ ○ nine",
      "│ ○ eight",
      "╰ ○ seven",
      "╭ ○ six",
      "│ ○ five",
      "╰ ○ four",
      "╭ ○ three",
      "│ ○ two",
      "╰ ○ one",
    ]
    assert expected == created
  end

  test "mark_done rotates tasks" do
    t1 = %Todo{label: "one"}
    t2 = %Todo{label: "two"}
    t3 = %Todo{label: "three", done?: true}

    assert [t2, t3, %{t1 | done?: true}] == mark_done!([t1, t2, t3])
  end
end

defmodule TodoParserTest do
  use ExUnit.Case
  import Todo.Parser, only: [parse: 1]

  test "strings go as is" do
    assert parse("what is this?") == %{label: "what is this?", hook: nil}
  end
  test "empty string" do
    assert parse("") == %{label: "", hook: nil}
  end
  test "todobqn hook" do
    assert parse("who what when todobqn:something here") == %{label: "who what when here", hook: [todobqn: "something"]}
  end
end
