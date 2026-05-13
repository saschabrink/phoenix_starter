defmodule Mix.Tasks.PhoenixStarter.Gen.CoreContextsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.PhoenixStarter.Gen.CoreContexts

  describe "phoenix_starter.gen.core_contexts" do
    test "declares ecto_context and static_context as installs" do
      info = CoreContexts.info([], nil)

      assert {:ecto_context, "~> 0.3"} in info.installs
      assert {:static_context, "~> 0.2"} in info.installs
    end
  end
end
