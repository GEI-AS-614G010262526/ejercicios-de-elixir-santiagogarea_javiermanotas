defmodule Eratostenes do

  @moduledoc """
  Implementation of concurrent version of the Sieve of Eratosthenes
  """

  # ============================================================================
  # Public Exports
  # ============================================================================

  def primos(n) when n < 2, do: []
  def primos(n) do
    head = spawn(fn () -> filtro(2) end)
    Enum.each(2..n, fn i -> send head, {:check, i} end)
    send head, {:end, self(), []}

    receive do
      {:result, l} -> l
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp filtro(num) do
    receive do
      {:check, i} -> if rem(i, num) != 0 do
        sig = spawn(fn () -> filtro(i) end)
        filtro(num, sig)
      else
        filtro(num)
      end

      {:end, sender, l} -> send sender, {:result, Enum.reverse([num | l])}
    end
  end

  defp filtro(num, sig) do
    receive do
      {:check, i} -> if rem(i, num) != 0 do
        send sig, {:check, i}
      end
      filtro(num, sig)

      {:end, sender, l} -> send sig, {:end, sender, [num | l]}
    end
  end
end
