defmodule GestorDeRecursos do
  @moduledoc """
  Module that implements a simple distributed fault-tolerant resource manager.
  """

  @type resource :: atom()

  # ============================================================================
  # Lifecycle Functions
  # ============================================================================
  @spec start([resource()]) :: {:ok, pid()}
  def start(resources) do
    pid = spawn(fn -> init(resources, []) end)

    case :global.register_name(:gestor, pid) do
      :yes -> {:ok, pid}
      :no -> {:error, :already_started}
    end
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @spec alloc() :: {:ok, resource()} | {:error, :sin_recursos}
  def alloc() do
    send(:global.whereis_name(:gestor), {:alloc, self()})

    receive do
      {:ok, resource} -> {:ok, resource}
      {:error, :sin_recursos} -> {:error, :sin_recursos}
    end
  end

  @spec release(resource()) :: :ok | {:error, :recurso_no_reservado}
  def release(resource) do
    send(:global.whereis_name(:gestor), {:release, self(), resource})

    receive do
      :ok -> :ok
      {:error, :recurso_no_reservado} -> {:error, :recurso_no_reservado}
    end
  end

  @spec avail() :: non_neg_integer()
  def avail() do
    send(:global.whereis_name(:gestor), {:avail, self()})

    receive do
      {:count, count} -> count
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================
  defp init(available, allocated) do
    Process.flag(:trap_exit, true)
    loop(available, allocated)
  end

  defp loop(available, allocated) do
    receive do
      {:alloc, from} ->
        available
        |> case do
          [] ->
            send(from, {:error, :sin_recursos})
            loop(available, allocated)
          [resource | rest] ->
            link_process_if_needed(from, allocated)
            send(from, {:ok, resource})
            loop(rest, [{resource, from} | allocated])
        end

      {:release, from, resource} ->
        List.keyfind(allocated, resource, 0)
        |> case do
          {^resource, ^from} when is_pid(from) ->
            new_allocated = List.keydelete(allocated, resource, 0)
            unlink_process_if_needed(from, new_allocated)
            send(from, :ok)
            loop([resource | available], new_allocated)
          _ ->
            send(from, {:error, :recurso_no_reservado})
            loop(available, allocated)
          end

      {:avail, from} ->
        send(from, {:count, length(available)})
        loop(available, allocated)

      {:nodedown, node} ->
        {to_free, new_allocated} = Enum.split_with(allocated, fn {_resource, p} -> node(p) == node end)
        freed_resources = Enum.map(to_free, fn {resource, _pid} -> resource end)
        loop(freed_resources ++ available, new_allocated)

      # Ignore noconnection message becouse we are already handling nodedown
      {:EXIT, _pid, :noconnection} ->
        loop(available, allocated)

      {:EXIT, pid, _reason} ->
        {to_free, new_allocated} = Enum.split_with(allocated, fn {_resource, p} -> p == pid end)
        freed_resources = Enum.map(to_free, fn {resource, _pid} -> resource end)
        loop(freed_resources ++ available, new_allocated)
    end
  end

  defp link_process_if_needed(pid, allocated) do
    case Enum.any?(allocated, fn {_resource, p} -> p == pid end) do
      true ->
        :ok
      false ->
        Process.link(pid)
        Node.monitor(node(pid), true)
    end
  end

  defp unlink_process_if_needed(pid, allocated) do
    case Enum.any?(allocated, fn {_resource, p} -> p == pid end) do
      true ->
        :ok
      false ->
        Process.unlink(pid)
        Node.monitor(node(pid), false)
    end
  end
end
