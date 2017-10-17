module Update exposing (update)

import Set
import List
import RemoteData exposing (WebData, RemoteData(..))
import Authentication exposing (isLoggedIn, tryGetUserProfile)
import Constants exposing (..)
import Models exposing (..)
import Msgs exposing (Msg)
import Helpers exposing (getUserNameForAuthModel, filterPokedex, searchPokedex)
import Ports exposing (preloadImages)
import Commands.Pokemon exposing (loadPokedex)
import Commands.Ratings exposing (saveRatings)


-- helper functions specific to Update


extractOneUserFromRatings : TeamRatings -> CurrentUser -> ( TeamRatings, TeamRatings )
extractOneUserFromRatings ratings currentUser =
    case currentUser of
        Nothing ->
            ( [], ratings )

        Just simpleUserName ->
            List.partition (.userName >> (==) simpleUserName) ratings


extractOnePokemonFromRatingString : String -> Int -> Int
extractOnePokemonFromRatingString ratingString pokemonNumber =
    String.slice pokemonNumber (pokemonNumber + 1) ratingString
        |> String.toInt
        |> Result.withDefault 0


putCurrentGenFirst : Int -> List PreloadCandidate -> List PreloadCandidate
putCurrentGenFirst gen imgList =
    let
        nr =
            gen - 1

        ( head, tail ) =
            List.partition (.generation >> (>) gen) imgList
    in
        tail ++ head



-- some update functions


updateOnLoadPokedex : ApplicationState -> WebData Pokedex -> ( ApplicationState, Cmd Msg )
updateOnLoadPokedex oldState pokedex =
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

        generationAndImageUrl p =
            let
                generation =
                    p.generation
            in
                List.map
                    (\v ->
                        { generation = generation
                        , imageUrl = v.image
                        }
                    )
                    p.variants

        command =
            case pokedex of
                Success actualPokedex ->
                    actualPokedex
                        |> List.map generationAndImageUrl
                        |> List.concat
                        |> putCurrentGenFirst oldState.generation
                        |> preloadImages

                _ ->
                    Cmd.none
    in
        ( newState, command )


updateSearchPokemon : ApplicationState -> String -> ( ApplicationState, Cmd Msg )
updateSearchPokemon oldState query =
    let
        newViewMode =
            if query == "" then
                Browse
            else
                Search

        newState =
            { oldState | query = query, viewMode = newViewMode }
    in
        ( newState, Cmd.none )


updateChangeVariant : ApplicationState -> Int -> BrowseDirection -> ( ApplicationState, Cmd Msg )
updateChangeVariant oldState pokemonNumber direction =
    let
        newState =
            case oldState.pokedex of
                Success pokedex ->
                    let
                        maybePokemon =
                            List.filter (.number >> (==) pokemonNumber) pokedex
                                |> List.head
                    in
                        case maybePokemon of
                            Nothing ->
                                oldState

                            Just pokemon ->
                                let
                                    proposedNewVariant =
                                        if direction == Next then
                                            pokemon.currentVariant + 1
                                        else
                                            pokemon.currentVariant - 1

                                    newVariant =
                                        if proposedNewVariant < 1 then
                                            List.length pokemon.variants
                                        else if proposedNewVariant > List.length pokemon.variants then
                                            1
                                        else
                                            proposedNewVariant

                                    newPokemon =
                                        { pokemon | currentVariant = newVariant }

                                    newPokedex =
                                        List.map
                                            (\p ->
                                                if p.number == pokemonNumber then
                                                    newPokemon
                                                else
                                                    p
                                            )
                                            pokedex
                                in
                                    { oldState | pokedex = RemoteData.succeed newPokedex }

                _ ->
                    oldState
    in
        ( newState, Cmd.none )


updateVoteForPokemon : ApplicationState -> UserVote -> ( ApplicationState, Cmd Msg )
updateVoteForPokemon oldState userVote =
    case oldState.ratings of
        Success oldRatings ->
            let
                -- GET THE REQUIRED DATA
                pokemonNumber =
                    userVote.pokemonNumber

                -- extract one user
                ( oldCurrentUserRatings, otherUserRatings ) =
                    extractOneUserFromRatings oldRatings oldState.user

                -- extract user rating string, or create one
                oldUserRatingString =
                    case List.head oldCurrentUserRatings of
                        Nothing ->
                            String.repeat totalPokemon "0"

                        Just actualUserRatings ->
                            actualUserRatings.ratings

                -- find new vote. If the same as old vote, clear it
                newPokeRating =
                    if oldPokeRating == userVote.vote then
                        0
                    else
                        userVote.vote

                -- CHECK IF VOTE HAS NOT ALREADY BEEN CAST
                ( generation, letter ) =
                    case oldState.pokedex of
                        Success actualPokedex ->
                            if oldState.viewMode == Browse then
                                let
                                    pokemon =
                                        List.filter (.number >> (==) pokemonNumber) actualPokedex
                                            |> List.head
                                            |> Maybe.withDefault
                                                { id = 0
                                                , number = 0
                                                , generation = 0
                                                , letter = '?'
                                                , name = ""
                                                , url = ""
                                                , currentVariant = 0
                                                , variants = []
                                                }
                                in
                                    ( pokemon.generation, pokemon.letter )
                            else
                                ( oldState.generation, oldState.letter )

                        _ ->
                            ( oldState.generation, oldState.letter )

                pokeList =
                    filterPokedex oldState.pokedex generation letter

                -- extract one pokemon rating
                oldPokeRating =
                    extractOnePokemonFromRatingString oldUserRatingString pokemonNumber

                otherPokemonRatings =
                    Set.fromList <|
                        List.map (.number >> extractOnePokemonFromRatingString oldUserRatingString) pokeList

                -- REGISTER NEW VOTE
                ( newState, newCmd ) =
                    if newPokeRating == 0 || not (Set.member newPokeRating otherPokemonRatings) then
                        case List.head oldCurrentUserRatings of
                            Nothing ->
                                ( oldState, Cmd.none )

                            Just actualUserRatings ->
                                let
                                    -- store new vote in rating string
                                    newUserRatingString =
                                        (String.slice 0 pokemonNumber oldUserRatingString)
                                            ++ (toString newPokeRating)
                                            ++ (String.slice (pokemonNumber + 1) (totalPokemon + 1) oldUserRatingString)

                                    -- insert into new state
                                    newCurrentUserRatings =
                                        { actualUserRatings | ratings = newUserRatingString }

                                    newStateRatings =
                                        newCurrentUserRatings :: otherUserRatings
                                in
                                    ( { oldState | ratings = Success newStateRatings, statusMessage = "" }
                                    , saveRatings newCurrentUserRatings
                                    )
                    else
                        ( { oldState
                            | statusMessage = "You already voted " ++ toString newPokeRating ++ " in this category"
                            , statusLevel = Warning
                          }
                        , Cmd.none
                        )
            in
                ( newState, newCmd )

        _ ->
            ( oldState, Cmd.none )



-- central update function


update : Msg -> ApplicationState -> ( ApplicationState, Cmd Msg )
update msg oldState =
    case msg of
        Msgs.OnLoadRatings NotAsked ->
            ( oldState, Cmd.none )

        Msgs.OnLoadRatings Loading ->
            ( oldState, Cmd.none )

        Msgs.OnLoadRatings (Success ratings) ->
            let
                newRatings =
                    RemoteData.succeed ratings

                userName =
                    getUserNameForAuthModel newRatings oldState.authModel

                newState =
                    { oldState | ratings = newRatings, user = userName }
            in
                ( newState, loadPokedex )

        Msgs.OnLoadRatings (Failure message) ->
            let
                newState =
                    { oldState
                        | statusMessage = toString message
                        , statusLevel = Error
                        , ratings = RemoteData.Failure message
                    }
            in
                ( newState, loadPokedex )

        Msgs.OnSaveRatings NotAsked ->
            ( oldState, Cmd.none )

        Msgs.OnSaveRatings Loading ->
            ( oldState, Cmd.none )

        Msgs.OnSaveRatings (Success ratings) ->
            ( oldState, Cmd.none )

        Msgs.OnSaveRatings (Failure message) ->
            let
                newState =
                    { oldState | statusMessage = toString message, statusLevel = Error }
            in
                ( newState, Cmd.none )

        Msgs.OnLoadPokedex pokedex ->
            updateOnLoadPokedex oldState pokedex

        Msgs.AuthenticationMsg authMsg ->
            let
                ( authModel, cmd ) =
                    Authentication.update authMsg oldState.authModel

                newState =
                    { oldState
                        | authModel = authModel
                        , user = getUserNameForAuthModel oldState.ratings authModel
                    }
            in
                ( newState, Cmd.map Msgs.AuthenticationMsg cmd )

        Msgs.ChangeGeneration newGen ->
            let
                newViewMode =
                    Browse

                newState =
                    if List.member newGen allGenerations then
                        { oldState
                            | generation = newGen
                            , statusMessage = ""
                            , statusLevel = None
                            , viewMode = newViewMode
                        }
                    else
                        oldState
            in
                ( newState, Cmd.none )

        Msgs.ChangeLetter newLetter ->
            let
                newViewMode =
                    Browse

                newState =
                    if List.member newLetter allLetters then
                        { oldState
                            | letter = newLetter
                            , statusMessage = ""
                            , statusLevel = None
                            , viewMode = newViewMode
                        }
                    else
                        oldState
            in
                ( newState, Cmd.none )

        Msgs.ChangeVariant pokemonNumber direction ->
            updateChangeVariant oldState pokemonNumber direction

        Msgs.SearchPokemon pattern ->
            updateSearchPokemon oldState pattern

        Msgs.VoteForPokemon userVote ->
            updateVoteForPokemon oldState userVote
