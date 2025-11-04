defmodule ServidoresFederadosDistributedTest do
  use ExUnit.Case
  doctest ServidoresFederados

  alias ServidoresFederados.Server
  alias ServidoresFederados.Models.Message

  @server_name "server"
  @example_username "john_doe"
  @example_user_fullname "Javier Manotas2"
  @example_avatar "avatar1.com"
  @remote_node_name :remote_node

  setup do
    unless Node.alive?() do
      {:ok, _pid} = Node.start(:"#{@server_name}@127.0.0.1")
      Node.set_cookie(:test_cookie)
      # Restart the application to have a server in a named node
      Application.stop(:servidores_federados)
    end

    :ok = Application.ensure_started(:servidores_federados)

    {:ok, remote_node} = add_remote_node_and_connect(@remote_node_name)

    on_exit(fn ->
      Application.stop(:servidores_federados)
      :slave.stop(remote_node)
      Node.stop()
    end)
    {:ok, remote_node: remote_node}
  end

  # ============================================================================
  # Distributed Tests
  # ============================================================================

  test "get profile from remote node", %{remote_node: remote_node} do
    remote_user = register_remote_user(remote_node, "federated_user", "Federated User", "avatar_remote.com")

    {:ok, local_user} =
      Server.register_user(@example_username, @example_user_fullname, @example_avatar)

    {:ok, profile} =
      Server.get_profile(local_user.perfil.id, remote_user.perfil.id)

    assert profile == remote_user.perfil
  end

  test "post message to remote user and retrieve it", %{remote_node: remote_node} do
    remote_user = register_remote_user(remote_node, "federated_user", "Federated User", "avatar_remote.com")

    {:ok, local_user} =
      Server.register_user(@example_username, @example_user_fullname, @example_avatar)

    assert :ok =
             Server.post_message(
               local_user.perfil.id,
               remote_user.perfil.id,
               "Hello remote!"
             )

    {:ok, inbox} =
      :rpc.call(remote_node, Server, :retrieve_messages, [remote_user.perfil.id])

    expected_from = local_user.perfil.id
    assert [%Message{from: ^expected_from, content: "Hello remote!"}] = inbox
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp register_remote_user(remote_node, username, full_name, avatar) do
    {:ok, user} =
      :rpc.call(remote_node, Server, :register_user, [username, full_name, avatar])

    user
  end

  defp add_remote_node_and_connect(node_name) do
    {:ok, remote_node} =
      :slave.start_link(~c'127.0.0.1', node_name, ~c'-setcookie test_cookie')

    :rpc.call(remote_node, :code, :add_paths, [:code.get_path()])

    :rpc.call(remote_node, Application, :ensure_all_started, [:servidores_federados])

    Node.connect(remote_node)
    {:ok, remote_node}
  end
end
