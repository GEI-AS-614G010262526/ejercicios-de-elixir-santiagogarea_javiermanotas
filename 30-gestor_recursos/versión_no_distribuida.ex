defmodule GestorDeRecursos do
  @moduledoc """
  Module that implements a simple resource manager.
  """

  @type resource :: atom()

  # ============================================================================
  # Lifecycle Functions
  # ============================================================================
  @spec start([resource()]) :: {:ok, pid()}
  def start(resources) do
    pid = spawn(fn -> loop(resources, []) end)

    :erlang.register(:gestor, pid)
    {:ok, pid}
  end

  # ============================================================================
  # Public API
  # ============================================================================

    @spec alloc() :: {:ok, resource()} | {:error, :sin_recursos}
    def alloc() do
      send(:gestor, {:alloc, self()})

      receive do
        {:ok, resource} -> {:ok, resource}
        {:error, :sin_recursos} -> {:error, :sin_recursos}
      end
    end

    @spec release(resource()) :: :ok | {:error, :recurso_no_reservado}
    def release(resource) do
      send(:gestor, {:release, self(), resource})

      receive do
        :ok -> :ok
        {:error, :recurso_no_reservado} -> {:error, :recurso_no_reservado}
      end
    end

    @spec avail() :: non_neg_integer()
    def avail() do
      send(:gestor, {:avail, self()})

      receive do
        {:count, count} -> count
      end
    end

  # ============================================================================
  # Private Functions
  # ============================================================================
  defp loop(available, allocated) do
      receive do
        {:alloc, from} ->
          available
          |> case do
            [] ->
              send(from, {:error, :sin_recursos})
              loop(available, allocated)
            [resource | rest] ->
              send(from, {:ok, resource})
              loop(rest, [{resource, from} | allocated])
          end

        {:release, from, resource} ->
          Keyword.get(allocated, resource, nil)
          |> case do
            ^from when is_pid(from) ->
              send(from, :ok)
              new_allocated = List.keydelete(allocated, resource, 0)
              loop([resource | available], new_allocated)
            _ ->
              send(from, {:error, :recurso_no_reservado})
              loop(available, allocated)
            end

        {:avail, from} ->
          send(from, {:count, length(available)})
          loop(available, allocated)
      end
    end
end
