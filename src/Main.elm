module Main exposing (main)

import Auth0
import Authentication
import Navigation exposing (programWithFlags, Location)
import RemoteData exposing (RemoteData(..))
import Constants exposing (initialGeneration, initialLetter)
import Models exposing (ApplicationState, StatusLevel(None), ViewMode(..))
import Ports exposing (auth0showLock, auth0logout, auth0authResult)
import View exposing (view)
import Update exposing (update, dissectLocationHash, hashToMsg)
import Msgs exposing (Msg)
import Commands exposing (loadAll)


init : Maybe Auth0.LoggedInUser -> Location -> ( ApplicationState, Cmd Msg )
init initialUser location =
    let
        authModel =
            Authentication.init auth0showLock auth0logout initialUser

        defaultSubpage =
            { generation = initialGeneration
            , letter = initialLetter
            }

        subpage =
            dissectLocationHash location defaultSubpage

        initialState : ApplicationState
        initialState =
            { authModel = authModel
            , user = Nothing
            , statusMessage = ""
            , statusLevel = None
            , viewMode = Browse
            , generation = subpage.generation
            , letter = subpage.letter
            , query = ""
            , pokedex = RemoteData.NotAsked
            , ratings = RemoteData.NotAsked
            }
    in
        ( initialState, loadAll )


subscriptions : ApplicationState -> Sub Msg
subscriptions state =
    auth0authResult (Authentication.handleAuthResult >> Msgs.AuthenticationMsg)


main : Program (Maybe Auth0.LoggedInUser) ApplicationState Msg
main =
    Navigation.programWithFlags
        hashToMsg
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
