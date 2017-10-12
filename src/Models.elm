module Models exposing (..)

import RemoteData exposing (WebData, RemoteData(..))
import Constants exposing (..)


type BrowseDirection
    = Next
    | Prev


type StatusLevel
    = Error
    | Warning
    | Notice
    | Debug
    | None


type alias LighthouseData =
    { name : String
    , caption : String
    }


type alias UserVote =
    { pokemonNumber : Int
    , vote : Int
    }


type alias CurrentUser =
    Maybe String


type alias UserRating =
    { id : Int
    , userName : String
    , email : String
    , color : String
    , rating : Int
    }


type alias UserRatings =
    { id : Int
    , userName : String
    , email : String
    , color : String
    , ratings : String
    }


type alias TeamRating =
    List UserRating


type alias TeamRatings =
    List UserRatings


type alias ApplicationState =
    { user : CurrentUser
    , statusMessage : String
    , statusLevel : StatusLevel
    , generation : Int
    , letter : Char
    , pokedex : WebData Pokedex
    , ratings : WebData TeamRatings
    }


type alias Pokemon =
    { id : Int
    , number : Int
    , generation : Int
    , letter : Char
    , name : String
    , url : String
    , currentVariant : Int
    , variants : List PokemonVariant
    }


type alias PokemonVariant =
    { image : String
    , vname : String
    }


type alias Pokedex =
    List Pokemon


initialState : ApplicationState
initialState =
    { user = Nothing
    , statusMessage = ""
    , statusLevel = None
    , generation = initialGeneration
    , letter = initialLetter
    , pokedex = NotAsked
    , ratings = NotAsked
    }
