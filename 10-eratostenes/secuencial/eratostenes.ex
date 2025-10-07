defmodule Eratostenes do

  def primos(n) when n < 2, do: []
  def primos(n) do
    criba(secuencia(2, n))
  end

  defp secuencia(n, n), do: [n]
  defp secuencia(n, m) do
    [n | secuencia(n + 1, m)]
  end

  defp criba([]), do: []
  defp criba([h | t]) do
    [h | sieve(Enum.filter(t, &rem(&1, h) != 0))]
  end

end
