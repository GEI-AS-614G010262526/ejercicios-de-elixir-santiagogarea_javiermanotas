defmodule ServidoresFederadosTest do
  use ExUnit.Case
  doctest ServidoresFederados

  alias ServidoresFederados.Server
  alias ServidoresFederados.Models.Message

  # The name of a VM without a name is "nonode"
  @server_name "nonode"
  @example_username "john_doe"
  @example_user_fullname "Javier Manotas2"
  @example_avatar "avatar1.com"

  setup %{} do

    Application.ensure_started(:servidores_federados)

    on_exit(fn ->
      Application.stop(:servidores_federados)
    end)

    :ok
  end

  # ============================================================================
  # Funcionalities Tests
  # ============================================================================

  test "get local own user profile" do
    {:ok, registered_user} =
      Server.register_user(
        @example_username,
        @example_user_fullname,
        @example_avatar
      )

    {:ok, profile} =
      Server.get_profile(
        registered_user.perfil.id,
        registered_user.perfil.id
      )

    assert profile == registered_user.perfil
    assert profile == %ServidoresFederados.Models.Actor.Perfil{
             id: "#{@example_username}@#{@server_name}",
             name: @example_user_fullname,
             avatar: @example_avatar
           }
  end

  test "get local other user profile" do
    {:ok, registered_user1} =
      Server.register_user(
        @example_username,
        @example_user_fullname,
        @example_avatar
      )

    {:ok, registered_user2} =
      Server.register_user(
        "elguille",
        "Guillermo Barrendero",
        "avatar2.com"
      )

    {:ok, profile} =
      Server.get_profile(
        registered_user1.perfil.id,
        registered_user2.perfil.id
      )

    assert profile == registered_user2.perfil
  end

  test "post message between users and retrieve inbox" do
    {:ok, registered_user1} =
      Server.register_user(
        @example_username,
        @example_user_fullname,
        @example_avatar
      )

    {:ok, registered_user2} =
      Server.register_user(
        "elguille",
        "Guillermo Barrendero",
        "avatar2.com"
      )

    expected_from = registered_user1.perfil.id
    assert :ok =
            Server.post_message(
              registered_user1.perfil.id,
              registered_user2.perfil.id,
              "Hello elguille!"
            )

    {:ok, inbox} = Server.retrieve_messages(registered_user2.perfil.id)
    assert [%Message{from: ^expected_from, content: "Hello elguille!"}] = inbox
  end

  # ============================================================================
  # Ensure Error Cases Tests
  # ============================================================================

  test "cannot register a user twice" do
    {:ok, _registered_user} =
      Server.register_user(
        @example_username,
        @example_user_fullname,
        @example_avatar
      )

    assert {:error, :user_already_exists} =
            Server.register_user(
              @example_username,
              @example_user_fullname,
              @example_avatar
            )
  end

  test "cannot post message if sender isn't in the system" do
    {:ok, registered_user} =
      Server.register_user(
        "elguille",
        "Guillermo Barrendero",
        "avatar2.com"
      )

    non_existing_id = "non_existing@#{@server_name}"

    assert {:error, :unauthorized} =
            Server.post_message(
              non_existing_id,
              registered_user.perfil.id,
              "Hi elguille!"
            )
  end

  test "cannot retrieve messages if user isn't in the system" do
    non_existing_id = "non_existing@#{@server_name}"
    assert {:error, :unauthorized} =
            Server.retrieve_messages(non_existing_id)
  end

  test "cannot get profile if requestor isn't in the system" do
    {:ok, registered_user} =
      Server.register_user(
        "elguille",
        "Guillermo Barrendero",
        "avatar2.com"
      )

    non_existing_id = "eve@#{@server_name}"

    assert {:error, :unauthorized} =
            Server.get_profile(
              non_existing_id,
              registered_user.perfil.id
            )
  end

  test "cannot get profile of non-existent user" do
    {:ok, registered_user} =
      Server.register_user(
        @example_username,
        @example_user_fullname,
        @example_avatar
      )

    fake_target = "nonexistent@#{@server_name}"

    assert {:error, :user_not_found} =
            Server.get_profile(
              registered_user.perfil.id,
              fake_target
            )
  end
end
