defmodule Servidor do

  @moduledoc """
  Module to manage a pool of worker processes to execute jobs concurrently.
  """

  # ============================================================================
  # Public Exports
  # ============================================================================

  @doc """
  Starts the server with a number of worker processes.
  """
  @spec start(integer()) :: {:ok, pid()}
  def start(n) do
    {:ok, spawn(fn -> init(n) end)}
  end

  @doc """
  Sends a batch of jobs to the server, returning a unique reference for the batch and
  when all jobs in the batch are completed, the results are sent back to the caller.
  """
  @spec run_batch(pid(), list()) :: {:ok, reference()}
  def run_batch(master, jobs) do
    ref = make_ref()
    send(master, {:trabajos, self(), ref, jobs})
    {:ok, ref}
  end

  @spec stop(pid()) :: :ok
  @doc """
  Stops all workers and the server forcibly.
  """
  def stop(master) do
    send(master, {:stop, self()})
    receive do
      :stopped ->
        :ok
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

    defp add_jobs(batch_ref, jobs, acc, from, new_jobs) do
      num_jobs = length(new_jobs)
      updated_jobs = jobs ++ [{batch_ref, from, Enum.with_index(new_jobs), num_jobs}]
      updated_acc = Map.put(acc, {batch_ref, from}, {[], num_jobs})
      {updated_jobs, updated_acc}
    end

    def init(n) do
      workers = Enum.map(1..n, &Trabajador.start(&1))
      loop(workers, workers, [], %{})
    end

    defp loop(workers, workers_pool, jobs, acc) do
      receive do
        {:trabajos, from, ref, new_jobs} ->
          {updated_jobs, updated_acc} = add_jobs(ref, jobs, acc, from, new_jobs)
          {updated_workers, updated_jobs2} = schedule_jobs(workers_pool, updated_jobs)
          loop(workers, updated_workers, updated_jobs2, updated_acc)
        {:job_result, {ref, from, client_pid, {position, result}}} ->
          new_acc = update_results_accumulator(acc, ref, client_pid, position, result)
          {new_workers, new_jobs} = schedule_jobs([from | workers], jobs)
          loop(workers, new_workers, new_jobs, new_acc)
        {:stop, from} ->
          stop_workers(workers)
          send(from, :stopped)
      end
    end

    defp schedule_jobs([], jobs), do: {[], jobs}

    defp schedule_jobs(workers, []), do: {workers, []}

    defp schedule_jobs(workers, [{_batch_ref, _from, [], _remaining_jobs} | rest_batches]) do
      schedule_jobs(workers, rest_batches)
    end

    defp schedule_jobs([worker | rest_workers], [{ref, from, [{job, position} | rest_jobs], remaining_jobs} | rest_batches]) do
      Trabajador.send_job(worker, {ref, from, {job, position}})
      schedule_jobs(rest_workers, [{ref, from, rest_jobs, remaining_jobs} | rest_batches])
    end

    defp stop_workers([]), do: :ok

    defp stop_workers([worker | rest]) do
      Trabajador.stop(worker)
      wait_for_stop()
      stop_workers(rest)
    end

    defp update_results_accumulator(acc, ref, from, position, result) do
      case Map.get(acc, {ref, from}) do
        {batch_results, 1} ->
          updated_batch_results =
            [{result, position} | batch_results]
          sorted = Enum.sort_by(updated_batch_results, fn {_res, pos} -> pos end)
          send(from, {:result, ref, Enum.map(sorted, fn {res, _pos} -> res end)})
          Map.delete(acc, {ref, from})
        {batch_results, remaining_jobs} ->
          updated_batch_results =
            [{result, position} | batch_results]
          Map.put(acc, {ref, from}, {updated_batch_results, remaining_jobs - 1})
      end
    end

    defp wait_for_stop() do
      receive do
        :stopped ->
          :ok
        _ -> # Discard unexpected messages
          wait_for_stop()
      end
    end
  end
