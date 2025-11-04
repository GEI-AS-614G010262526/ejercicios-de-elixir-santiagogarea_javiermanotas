defmodule ServidoresFederados.Models.Message do
  @moduledoc """
  Message Model
  """

  @type t :: %__MODULE__{
          from: String.t(),
          content: any(),
  }

  defstruct [
    :from,
    :content
  ]
end
