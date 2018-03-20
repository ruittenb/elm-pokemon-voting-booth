module View.Application exposing (heading)

import Time exposing (Time, second)
import Html exposing (..)
import Html.Attributes exposing (attribute, id, href, class, classList, tabindex, placeholder, disabled)
import Html.Events exposing (onClick, onInput, onSubmit)
import Authentication exposing (tryGetUserProfile, isLoggedIn)
import RemoteData exposing (WebData, RemoteData(..))
import Control.Debounce exposing (trailing)
import Helpers exposing (filterPokedex, romanNumeral)
import Msgs exposing (Msg(..))
import Models exposing (..)
import Models.Types exposing (..)
import Models.Pokedex exposing (..)
import Constants exposing (..)


messageBox : String -> StatusLevel -> Html Msg
messageBox message level =
    let
        autohide =
            String.length message > 0 && level /= Error
    in
        span [ id "message-box-container" ]
            [ span
                [ id "message-box"
                , classList
                    [ ( "autohide", autohide )
                    , ( "debug", level == Debug )
                    , ( "notice", level == Notice )
                    , ( "warning", level == Warning )
                    , ( "error", level == Error )
                    ]
                ]
                [ text message ]
            ]


romanNumeralButton : ViewMode -> Int -> Char -> Int -> Html Msg
romanNumeralButton viewMode currentGen currentLetter gen =
    let
        currentHighLight =
            gen == currentGen && viewMode == Browse

        hash =
            "#" ++ (toString gen) ++ (String.fromChar currentLetter)
    in
        a
            [ classList
                [ ( "button", True )
                , ( "generation-button", True )
                , ( "current", currentHighLight )
                , ( "transparent", gen == 0 )
                ]
            , href hash
            ]
            [ text <| romanNumeral gen ]


debounce : Msg -> Msg
debounce =
    Control.Debounce.trailing
        DebounceSearchPokemon
        (debounceDelay * Time.second)


searchBox : ViewMode -> Html Msg
searchBox viewMode =
    span
        [ id "search-box-container"
        , classList [ ( "focus", viewMode == Search ) ]
        ]
        [ input
            [ id "search-box"
            , classList [ ( "current", viewMode == Search ) ]
            , placeholder "Search in pokédex"
            , Html.Attributes.map debounce <| onInput Msgs.SearchPokemon
            ]
            []
        ]


romanNumeralButtons : ViewMode -> Int -> Char -> Html Msg
romanNumeralButtons viewMode currentGen currentLetter =
    div [ id "generation-buttons" ] <|
        (List.map
            (romanNumeralButton viewMode currentGen currentLetter)
            allGenerations
        )
            ++ [ searchBox viewMode ]


letterButton : ViewMode -> WebData Pokedex -> Int -> Char -> Char -> Html Msg
letterButton viewMode pokedex currentGen currentLetter letter =
    let
        currentHighLight =
            letter == currentLetter && viewMode == Browse

        pokeList =
            filterPokedex pokedex currentGen letter

        hash =
            "#" ++ (toString currentGen) ++ (String.fromChar letter)

        linkElem =
            if List.isEmpty pokeList then
                span
            else
                a
    in
        linkElem
            [ classList
                [ ( "button", True )
                , ( "letter-button", True )
                , ( "current", currentHighLight )
                , ( "disabled", List.isEmpty pokeList )
                ]
            , href hash
            ]
            [ text <| String.fromChar letter ]


letterButtons : ViewMode -> WebData Pokedex -> Int -> Char -> Html Msg
letterButtons viewMode pokedex currentGen currentLetter =
    let
        buttonList =
            case pokedex of
                Success pokeList ->
                    List.map
                        (letterButton viewMode pokedex currentGen currentLetter)
                        allLetters

                _ ->
                    []
    in
        div [ id "letter-buttons" ] buttonList


loginLogoutButton : Authentication.Model -> CurrentUser -> String -> StatusLevel -> Html Msg
loginLogoutButton authModel user message level =
    let
        loggedIn =
            isLoggedIn authModel

        userName =
            if not loggedIn then
                "Not logged in"
            else
                Maybe.map ((++) "Logged in as ") user
                    |> Maybe.withDefault "Not authorized"

        buttonText =
            if loggedIn then
                "Logout"
            else
                "Login"

        buttonMsg =
            if loggedIn then
                Authentication.LogOut
            else
                Authentication.ShowLogIn
    in
        div [ id "user-buttons" ] <|
            [ div
                [ id "user-name"
                , classList
                    [ ( "current", loggedIn )
                    ]
                ]
                [ text userName ]
            , button
                [ class "user-button"
                , onClick (Msgs.AuthenticationMsg buttonMsg)
                ]
                [ text buttonText ]
            , messageBox message level
            ]


heading : ApplicationState -> Html Msg
heading state =
    div [ id "filter-buttons" ]
        [ loginLogoutButton
            state.authModel
            state.user
            state.statusMessage
            state.statusLevel
        , romanNumeralButtons
            state.viewMode
            state.generation
            state.letter
        , letterButtons
            state.viewMode
            state.pokedex
            state.generation
            state.letter
        ]
