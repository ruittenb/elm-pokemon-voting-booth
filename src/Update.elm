module Update exposing (update)

import RemoteData exposing (RemoteData(..))
import Constants exposing (..)
import Models exposing (..)
import Msgs exposing (Msg)
import CommandsPokemon exposing (loadPokedex)


-- import CommandsRatings exposing (saveRatings)


extractOneUserFromRatings : TeamRatings -> CurrentUser -> List UserRatings
extractOneUserFromRatings ratings currentUser =
    case currentUser of
        Nothing ->
            []

        Just simpleUserName ->
            List.filter (.userName >> (==) simpleUserName) ratings


extractOtherUsersFromRatings : TeamRatings -> CurrentUser -> List UserRatings
extractOtherUsersFromRatings ratings currentUser =
    case currentUser of
        Nothing ->
            ratings

        Just simpleUserName ->
            List.filter (.userName >> (/=) simpleUserName) ratings


update : Msg -> ApplicationState -> ( ApplicationState, Cmd Msg )
update msg oldState =
    case msg of
        Msgs.OnLoadRatings ratings ->
            let
                ( statusMessage, statusLevel ) =
                    case ratings of
                        NotAsked ->
                            ( "Preparing...", Notice )

                        Loading ->
                            ( "Loading...", Notice )

                        Success _ ->
                            ( "", None )

                        Failure mess ->
                            ( toString mess, Error )

                newState =
                    { oldState
                        | statusMessage = statusMessage
                        , statusLevel = statusLevel
                        , ratings = ratings
                    }
            in
                ( newState, loadPokedex )

        Msgs.OnLoadPokedex pokedex ->
            let
                ( statusMessage, statusLevel ) =
                    case pokedex of
                        NotAsked ->
                            ( "Preparing...", Notice )

                        Loading ->
                            ( "Loading...", Notice )

                        Failure mess ->
                            ( toString mess, Error )

                        Success _ ->
                            ( "", None )

                newState =
                    { oldState
                        | pokedex = pokedex
                        , statusMessage = statusMessage
                        , statusLevel = statusLevel
                    }
            in
                ( newState, Cmd.none )

        Msgs.ChangeUser newUser ->
            let
                newState =
                    case oldState.ratings of
                        Success actualRatings ->
                            if
                                List.map .userName actualRatings
                                    |> List.member newUser
                            then
                                { oldState | user = Just newUser }
                            else
                                oldState

                        _ ->
                            oldState
            in
                ( newState, Cmd.none )

        Msgs.ChangeGeneration newGen ->
            let
                newState =
                    { oldState | generation = newGen }
            in
                if List.member newGen allGenerations then
                    ( newState, Cmd.none )
                else
                    ( oldState, Cmd.none )

        Msgs.ChangeLetter newLetter ->
            let
                newState =
                    { oldState | letter = newLetter }
            in
                if List.member newLetter allLetters then
                    ( newState, Cmd.none )
                else
                    ( oldState, Cmd.none )

        Msgs.VoteForPokemon userVote ->
            case oldState.ratings of
                Success oldRatings ->
                    let
                        pokemonNumber =
                            userVote.pokemonNumber

                        -- extract one user
                        oldCurrentUserRatings =
                            extractOneUserFromRatings oldRatings oldState.user
                                |> List.head

                        -- the list of the other users
                        otherUserRatings =
                            extractOtherUsersFromRatings oldRatings oldState.user

                        -- extract user rating string, or create one
                        oldUserRatingString =
                            case oldCurrentUserRatings of
                                Nothing ->
                                    String.repeat totalPokemon "0"

                                Just actualUserRatings ->
                                    actualUserRatings.ratings

                        -- extract one pokemon rating
                        oldPokeRating =
                            String.slice pokemonNumber (pokemonNumber + 1) oldUserRatingString
                                |> String.toInt
                                |> Result.withDefault 0

                        -- find new vote. If the same as old vote, clear it
                        newPokeRating =
                            if oldPokeRating == userVote.vote then
                                0
                            else
                                userVote.vote

                        -- store new vote in rating string
                        newUserRatingString =
                            (String.slice 0 pokemonNumber oldUserRatingString)
                                ++ (toString newPokeRating)
                                ++ (String.slice (pokemonNumber + 1) (totalPokemon + 1) oldUserRatingString)

                        -- insert into new state
                        newState =
                            case oldCurrentUserRatings of
                                Nothing ->
                                    oldState

                                Just actualUserRatings ->
                                    let
                                        newCurrentUserRatings =
                                            { actualUserRatings | ratings = newUserRatingString }

                                        newStateRatings =
                                            newCurrentUserRatings :: otherUserRatings
                                    in
                                        { oldState | ratings = Success newStateRatings, statusMessage = "" }
                    in
                        ( newState, Cmd.none )

                -- .. or oldState.ratings not successfully loaded
                _ ->
                    ( oldState, Cmd.none )



{-
   ( newState, saveRatings newStateRatings )
-}
