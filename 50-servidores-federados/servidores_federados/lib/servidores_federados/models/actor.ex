defmodule ServidoresFederados.Models.Actor do
  @moduledoc """
  User Actor Model
  """

  alias ServidoresFederados.Models.Actor.Perfil
  alias ServidoresFederados.Models.Message

  @type t :: %__MODULE__{
          perfil: Perfil.t(),
          inbox: [Message.t()]
  }

  defstruct [
    :perfil,
    :inbox
  ]
end

defmodule ServidoresFederados.Models.Actor.Perfil do
  @moduledoc """
  User Actor
  """

  @type id :: String.t()
  @type avatar :: URI.t()

  @type t :: %__MODULE__{
          id: id(),
          name: String.t(),
          avatar: avatar()
  }

  defstruct [
    :id,
    :name,
    :avatar
  ]
end
