module Update exposing (update)

import Date exposing (Date, fromTime)
import Date.Extra exposing (toIsoString)
import List.Extra exposing (replaceIf)
import RemoteData exposing (WebData, RemoteData(..))
import Navigation exposing (newUrl)
import Control exposing (update)
import Constants exposing (maintenanceApology)
import Constants.Pages exposing (defaultPage)
import Models exposing (..)
import Models.Pages exposing (RemotePages)
import Models.Types exposing (..)
import Msgs exposing (Msg(..))
import Routing exposing (createSearchPath, createBrowsePath, createDefaultPath)
import Commands exposing (andThenCmd, getTodayTimeCmd)
import Commands.Database
    exposing
        ( firebaseInit
        , firebaseLoginWithJwtToken
        , firebaseLoginWithFirebaseToken
        , firebaseLogout
        )
import Helpers exposing (setStatusMessage, clearStatusMessage)
import Helpers.Authentication exposing (getUserNameForAuthModel)
import Helpers.Pages exposing (getDefaultPageForToday)
import Helpers.Pokemon
    exposing
        ( extractOneUserFromRatings
        , extractOnePokemonFromRatingString
        )
import Update.Authentication exposing (updateAuthWithProfile, updateAuthWithNoProfile)
import Update.Settings exposing (updateMaintenanceMode)
import Update.Ratings exposing (updateVoteForPokemon)
import Update.Pages exposing (updatePageLockState, updatePageWithWinner)
import Update.Pokemon
    exposing
        ( updateOnLoadPokedex
        , updateChangeGenerationAndLetter
        , updateSearchPokemon
        , updateChangeVariant
        )


resolveDefaultPage : Route -> Maybe SubPage -> RemotePages -> Date -> ( Maybe SubPage, Cmd Msg )
resolveDefaultPage currentRoute oldSubPage pages todayDate =
    -- if    currentRoute == Default or Search
    -- and   pages == Success x
    -- and   a page can be found for this todayDate
    -- then  set the subpage
    -- and   if Default then navigate to a Browse page.
    let
        maybeDefaultPageForToday =
            getDefaultPageForToday pages todayDate

        ( maybeDefaultSubPageForToday, hash ) =
            maybeDefaultPageForToday
                |> Maybe.map
                    (\page ->
                        ( Just
                            { generation = page.generation
                            , letter = page.letter
                            }
                        , createBrowsePath page.generation page.letter
                        )
                    )
                |> Maybe.withDefault
                    ( oldSubPage, "" )
    in
        case currentRoute of
            Default ->
                if maybeDefaultPageForToday == Nothing then
                    ( oldSubPage, Cmd.none )
                else
                    ( maybeDefaultSubPageForToday
                    , newUrl hash
                    )

            Search _ ->
                ( maybeDefaultSubPageForToday, Cmd.none )

            _ ->
                ( oldSubPage, Cmd.none )


update : Msg -> ApplicationState -> ( ApplicationState, Cmd Msg )
update msg maybeHighlightedState =
    let
        oldState =
            case msg of
                Tick _ ->
                    maybeHighlightedState

                _ ->
                    { maybeHighlightedState | highlightedUserId = Nothing }
    in
        case msg of
            AuthenticationReceived (Ok credentials) ->
                updateAuthWithProfile oldState credentials
                    |> andThenCmd (firebaseLoginWithJwtToken credentials.idToken)

            AuthenticationReceived (Err error) ->
                updateAuthWithNoProfile oldState (Just error)
                    |> andThenCmd firebaseLogout

            AuthenticationFailed reason ->
                updateAuthWithNoProfile oldState (Just reason)
                    |> andThenCmd firebaseLogout

            AuthenticationLogoutClicked ->
                updateAuthWithNoProfile oldState Nothing
                    |> andThenCmd firebaseLogout

            AuthenticationLoginClicked ->
                ( oldState
                , oldState.authModel.showLock oldState.authModel.lockParameters
                )

            FirebaseLoginFailed reason ->
                updateAuthWithNoProfile oldState (Just reason)
                    |> andThenCmd firebaseLogout

            SettingsLoaded (Success settings) ->
                let
                    newState =
                        { oldState | settings = RemoteData.succeed settings }

                    newTuple =
                        if not settings.maintenanceMode then
                            ( newState, Cmd.none )
                                |> clearStatusMessage
                        else
                            ( newState, Cmd.none )
                                |> setStatusMessage Maintenance maintenanceApology
                in
                    newTuple

            SettingsLoaded (Failure message) ->
                let
                    newState =
                        { oldState
                            | ratings = RemoteData.Failure message
                        }
                in
                    ( newState, Cmd.none )
                        |> setStatusMessage Error (toString message)

            SettingsLoaded _ ->
                ( oldState, Cmd.none )

            PagesLoaded (Success pages) ->
                let
                    -- Check if the current route needs replacing with a browse route.
                    ( newSubPage, urlCommand ) =
                        oldState.todayDate
                            |> Maybe.map
                                (resolveDefaultPage oldState.currentRoute oldState.subPage (Success pages))
                            |> Maybe.withDefault ( oldState.subPage, Cmd.none )

                    newState =
                        { oldState
                            | pages = RemoteData.succeed pages
                            , subPage = newSubPage
                        }
                in
                    ( newState, urlCommand )

            PagesLoaded (Failure message) ->
                let
                    newState =
                        { oldState
                            | pages = RemoteData.Failure message
                        }
                in
                    ( newState, Cmd.none )
                        |> setStatusMessage Error (toString message)

            PagesLoaded _ ->
                ( oldState, Cmd.none )

            PageLoaded (Success page) ->
                let
                    newPages =
                        RemoteData.map
                            (replaceIf (.id >> (==) page.id) page)
                            oldState.pages

                    newState =
                        { oldState | pages = newPages }
                in
                    ( newState, Cmd.none )

            PageLoaded (Failure message) ->
                ( oldState, Cmd.none )
                    |> setStatusMessage Error (toString message)

            PageLoaded _ ->
                ( oldState, Cmd.none )

            TeamRatingsLoaded (Success ratings) ->
                let
                    newRatings =
                        RemoteData.succeed ratings

                    userName =
                        getUserNameForAuthModel newRatings oldState.authModel

                    newState =
                        { oldState | ratings = newRatings, currentUser = userName }
                in
                    ( newState, Cmd.none )

            TeamRatingsLoaded (Failure message) ->
                let
                    newState =
                        { oldState
                            | ratings = RemoteData.Failure message
                        }
                in
                    ( newState, Cmd.none )
                        |> setStatusMessage Error (toString message)

            TeamRatingsLoaded _ ->
                ( oldState, Cmd.none )

            UserRatingsLoaded (Success userRatings) ->
                let
                    newRatings =
                        RemoteData.map
                            (replaceIf (.id >> (==) userRatings.id) userRatings)
                            oldState.ratings

                    newState =
                        { oldState | ratings = newRatings }
                in
                    ( newState, Cmd.none )

            NotificationsClicked ->
                -- TODO
                ( oldState, Cmd.none )
                    |> setStatusMessage Debug "Toggle notifications"

            VariantChanged pokemonNumber direction ->
                updateChangeVariant oldState pokemonNumber direction

            PokedexLoaded pokedex ->
                updateOnLoadPokedex oldState pokedex

            UserHighlightClicked id ->
                let
                    newState =
                        { oldState | highlightedUserId = Just id }
                in
                    ( newState, Cmd.none )

            UrlChanged newRoute ->
                case newRoute of
                    Default ->
                        -- invalid URL? fetch today's date, which will reload the default page
                        ( { oldState | currentRoute = newRoute }
                        , getTodayTimeCmd
                        )

                    Search query ->
                        updateSearchPokemon oldState query

                    _ ->
                        updateChangeGenerationAndLetter oldState newRoute

            CloseMaskClicked ->
                let
                    ( browsePath, browseSubPage ) =
                        case oldState.subPage of
                            Just subPage ->
                                ( createBrowsePath subPage.generation subPage.letter
                                , Browse Freely
                                    { generation = subPage.generation
                                    , letter = subPage.letter
                                    }
                                )

                            Nothing ->
                                ( createDefaultPath
                                , Default
                                )
                in
                    ( { oldState | currentRoute = browseSubPage }
                    , newUrl browsePath
                    )

            PageLockClicked page ->
                updatePageLockState oldState page

            WinnerElected page winner ->
                updatePageWithWinner oldState page winner

            MaintenanceModeClicked ->
                updateMaintenanceMode oldState

            VariantChanged pokemonNumber direction ->
                updateChangeVariant oldState pokemonNumber direction

            SearchPokemon query ->
                updateSearchPokemon oldState query
                    |> andThenCmd (newUrl <| createSearchPath query)

            DebounceSearchPokemon debMsg ->
                Control.update
                    (\s -> { oldState | debounceState = s })
                    oldState.debounceState
                    debMsg

            PokemonVoteCast userVote ->
                updateVoteForPokemon oldState userVote

            UserRatingsSaved (Failure message) ->
                ( oldState, Cmd.none )
                    |> setStatusMessage Error (toString message)

            UserRatingsSaved _ ->
                ( oldState, Cmd.none )

            TodayReceived time ->
                let
                    todayDate =
                        Date.fromTime time

                    -- Check if the current route needs replacing with a browse route.
                    ( newSubPage, urlCommand ) =
                        resolveDefaultPage oldState.currentRoute oldState.subPage oldState.pages todayDate

                    newState =
                        { oldState
                            | todayDate = Just todayDate
                            , subPage = newSubPage
                        }
                in
                    ( newState, urlCommand )

            StatusMessageExpiryTimeReceived time ->
                let
                    newState =
                        { oldState | statusExpiryTime = Just time }
                in
                    ( newState, Cmd.none )

            Tick time ->
                if Maybe.map ((>) time) oldState.statusExpiryTime == Just True then
                    ( oldState, Cmd.none )
                        |> clearStatusMessage
                else
                    ( oldState, Cmd.none )
