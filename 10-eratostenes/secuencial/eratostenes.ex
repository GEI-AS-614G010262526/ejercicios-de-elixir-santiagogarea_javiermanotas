defmodule Eratostenes do

  @moduledoc """
  Implementation of concurrent version of the Sieve of Eratosthenes
  """

  # ============================================================================
  # Public Exports
  # ============================================================================

  def primos(n) when n < 2, do: []
  def primos(n) do
    criba(secuencia(2, n))
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp secuencia(n, n), do: [n]
  defp secuencia(n, m) do
    [n | secuencia(n + 1, m)]
  end

  defp criba([]), do: []
  defp criba([h | t]) do
    [h | sieve(Enum.filter(t, &rem(&1, h) != 0))]
  end

end
