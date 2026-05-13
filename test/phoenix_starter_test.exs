defmodule PhoenixStarterTest do
  use ExUnit.Case
  doctest PhoenixStarter

  test "greets the world" do
    assert PhoenixStarter.hello() == :world
  end
end
