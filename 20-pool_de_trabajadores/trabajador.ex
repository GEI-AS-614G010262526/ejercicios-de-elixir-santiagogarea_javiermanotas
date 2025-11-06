defmodule Trabajador do

  @moduledoc """
  Worker module to execute individual jobs.
  """

  # ============================================================================
  # Public Exports
  # ============================================================================

  @doc """
  Starts a worker process with a given name.
  """
  @spec start(integer()) :: pid()
  def start(name) do
    spawn(fn -> loop(name) end)
  end

  @doc """
  Sends a job to the worker process.
  """
  @spec send_job(pid(), {reference(), pid(), {(() -> any()), non_neg_integer()}}) :: :ok
  def send_job(worker, {ref, from, {job, position}}=payload) do
    send(worker, {:trabajo, self(), payload})
  end

  @doc """
  Stops the worker process.
  """
  @spec stop(pid()) :: :ok
  def stop(worker) do
    send(worker, {:stop, self()})
  end

  # ============================================================================
  # Private Functions
  # ============================================================================
  defp loop(name) do
    receive do
      {:trabajo, master, {ref, client_pid, {job, position}}} ->
        result = job.()
        send(master, {:job_result, {ref, self(), client_pid, {position, result}}})
        loop(name)

      {:stop, from} ->
        send(from, :stopped)
        :ok
    end
  end
end
