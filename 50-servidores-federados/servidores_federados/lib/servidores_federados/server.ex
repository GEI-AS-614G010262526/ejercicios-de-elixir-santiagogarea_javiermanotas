defmodule ServidoresFederados.Server do
  @moduledoc """
  Module that implements a Federated Server.

  It allows:
   - Registering users
   - Retrieving user profiles (local and remote)
   - Posting messages to other users (local and remote)
   - Retrieving own messages (only local)

  Something important to note is that the user_id is built as "username@server_name",
  where server_name is the short name of the node where the user is registered. For
  this reason, the different nodes must be connected to each other in the moment of
  making requests to remote users because the server find the larger node name from
  the user_id and the list of connected nodes.
  """

  use GenServer

  alias ServidoresFederados.Models.Actor
  alias ServidoresFederados.Models.Actor.Perfil
  alias ServidoresFederados.Models.Message

  # ============================================================================
  # Public Exports
  # ============================================================================

  @doc """
  Starts the Federated Server with the short name of the current node.
  """
  @spec start_link(any()) :: {:ok, pid()} | {:error, any()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{name: server_name(), users: %{}}, name: server_name())
  end

  @doc """
  Registers a new user in the server.
  """
  @spec register_user(Perfil.id(), String.t(), Perfil.avatar()) :: {:ok, Actor.t()} | {:error, any()}
  def register_user(username, full_name, user_avatar) do
    GenServer.call(server_name(), {:register_user, {username, full_name, user_avatar}})
  end

  @doc """
  Retrieves the profile of a user if the requestor is registered on the server.
  """
  @spec get_profile(Perfil.id(), Perfil.id()) :: {:ok, Perfil.t()} | {:error, any()}
  def get_profile(requestor, user_id),
    do: GenServer.call(server_name(), {:get_profile, requestor, user_id})

  @doc """
  Posts a message from sender to receiver if the sender is registered on the server.
  """
  @spec post_message(Perfil.id(), Perfil.id(), any()) :: :ok | {:error, any()}
  def post_message(sender, receiver, msg),
    do: GenServer.call(server_name(), {:post_message, sender, receiver, msg})

  @doc """
  Retrieves all messages for a user if the user is registered on the server.
  """
  @spec retrieve_messages(Perfil.id()) :: {:ok, [any()]} | {:error, any()}
  def retrieve_messages(user_id),
    do: GenServer.call(server_name(), {:retrieve_messages, user_id})

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  def init(state), do: {:ok, state}

  def handle_call({:register_user, {username, fullname, user_avatar}}, _from, state) do
    user_id = "#{username}@#{server_name()}"
    case Map.has_key?(state.users, user_id) do
      true ->
        {:reply, {:error, :user_already_exists}, state}
      false ->
        user = %Actor{
          perfil: %Actor.Perfil{id: user_id, name: fullname, avatar: user_avatar},
          inbox: []
        }
        new_state = %{state | users: Map.put(state.users, user_id, user)}
        {:reply, {:ok, user}, new_state}
    end
  end

  def handle_call({:get_profile, requestor, user_id}, _from, state) do
    case check_authorization(state, requestor) do
      true ->
        case get_user(user_id, state) do
          %Actor{} = user ->
            {:reply, {:ok, user.perfil}, state}
          {:error, :remote_user} ->
            case get_remote_profile(state.name, user_id) do
              {:ok, perfil} ->
                {:reply, {:ok, perfil}, state}
              {:error, reason} ->
                {:reply, {:error, reason}, state}
            end
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      false ->
        {:reply, {:error, :unauthorized}, state}
    end
  end

  def handle_call({:post_message, sender, receiver, msg}, _from, state) do
    case check_authorization(state, sender) do
      true ->
        case get_user(receiver, state) do
          %Actor{inbox: inbox} = user ->
            updated_user = %{user | inbox: [%Message{from: sender, content: msg} | inbox]}
            new_state = %{state | users: Map.put(state.users, receiver, updated_user)}
            {:reply, :ok, new_state}
          {:error, :remote_user} ->
            case post_message_to_remote(state.name, sender, receiver, msg) do
              :ok ->
                {:reply, :ok, state}
              {:error, reason} ->
                {:reply, {:error, reason}, state}
              end
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      false ->
        {:reply, {:error, :unauthorized}, state}
    end
  end

  def handle_call({:retrieve_messages, user_id}, _from, state) do
    case check_authorization(state, user_id) do
      true ->
        case get_user(user_id, state) do
          %Actor{inbox: inbox} -> {:reply, {:ok, inbox}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
      false ->
        {:reply, {:error, :unauthorized}, state}
    end
  end

  def handle_call({:get_profile_from_server, _server, user_id}, _from, state) do
    case get_user(user_id, state) do
      %Actor{} = user ->
        {:reply, {:ok, user.perfil}, state}
      {:error, reason} ->
          {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:post_message_from_server, _server, sender, receiver, msg}, _from, state) do
    case get_user(receiver, state) do
      %Actor{inbox: inbox} = user ->
        updated_user = %{user | inbox: [%Message{from: sender, content: msg} | inbox]}
        new_state = %{state | users: Map.put(state.users, receiver, updated_user)}
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================
  defp check_authorization(state, requestor),
    do: Map.has_key?(state.users, requestor)

  defp get_remote_profile(server, user_id) do
    case find_node(server_name_from_user_id(user_id)) do
      nil -> {
        :error, :server_not_found}
      node ->
        GenServer.call({username_to_server(user_id), node}, {:get_profile_from_server, server, user_id})
    end
   end

  defp get_user(user_id, state) do
     case local_user?(user_id) do
       true -> Map.get(state.users, user_id) || {:error, :user_not_found}
       false -> {:error, :remote_user}
     end
   end

  defp local_user?(user_id) do
    String.ends_with?(user_id, "@#{server_name()}")
   end

  defp find_node(server) do
    # Suppose that all nodes are connected
    Node.list()
    |> Enum.find(
      fn n ->
        Atom.to_string(n)
        |> String.starts_with?(to_string(server))
      end
    )
   end

  def server_name() do
    Node.self()
    |> Atom.to_string()
    |> String.split("@")
    |> List.first()
    |> String.to_atom()
   end

  def server_name_from_user_id(id) do
    [_, domain] = String.split(id, "@")
    String.to_atom("#{domain}")
   end

  defp post_message_to_remote(server, sender, receiver, msg) do
    case find_node(server_name_from_user_id(receiver)) do
      nil -> {:error, :server_not_found}
      node ->
        GenServer.call({username_to_server(receiver), node}, {:post_message_from_server, server, sender, receiver, msg})
    end
   end

   defp username_to_server(user_id) do
    [_, domain] = String.split(user_id, "@")
    String.to_atom("#{domain}")
   end
end
