module View.Pokemon exposing (pokemonCanvas)

import List
import Maybe
import Date
import Date.Extra
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData, RemoteData(..))
import Constants exposing (maxStars, imageDir, thumbnailDir, noBreakingSpace, dateTemplate)
import Helpers exposing (romanNumeral)
import Helpers.Pages exposing (isPageLocked, getCurrentPage, getWinner)
import Helpers.Pokemon
    exposing
        ( filterPokedexIfReady
        , searchPokedexIfReady
        , extractOneUserFromRating
        )
import Models exposing (..)
import Models.Types exposing (..)
import Models.Pokemon exposing (..)
import Models.Pages exposing (..)
import Models.Ratings exposing (..)
import Msgs exposing (Msg(..))
import Routing exposing (createBrowsePath)


emptyCanvas : List (Html Msg)
emptyCanvas =
    [ div [ class "empty-canvas" ]
        [ span [] [ text "No Pokémon in this page" ]
        ]
    ]


loadingBusyIcon : Html Msg
loadingBusyIcon =
    div [ class "loading-busy" ] []


loadingErrorIcon : Html Msg
loadingErrorIcon =
    div [ class "loading-error" ] []


unknownUserIcon : Html Msg
unknownUserIcon =
    div [ class "unknown-user" ] []


linkTo : String -> Html Msg -> Html Msg
linkTo url content =
    a
        [ href url
        , target "_blank"
        , rel "noopener"
        ]
        [ content ]


linkToLightbox : String -> String -> String -> Html Msg -> Html Msg
linkToLightbox imageUrl title caption content =
    a
        [ href imageUrl
        , attribute "data-mediabox" "pokemon"
        , attribute "data-title" title
        , attribute "data-caption" caption
        , attribute "aria-label" "image"
        ]
        [ content ]


pokemonImg : String -> String -> Html Msg
pokemonImg imageUrl altText =
    img
        [ src imageUrl
        , class "pokemon-image"
        , alt altText
        , title altText
        ]
        []


voteWidgetStar : Int -> String -> Int -> Int -> Html Msg
voteWidgetStar pokemonNumber currentUserName rating stars =
    span
        [ classList
            [ ( "star", True )
            , ( "fa", True )
            , ( "fa-star-o", rating < stars )
            , ( "fa-star", rating >= stars )
            , ( "selected", rating >= stars )
            ]
        , onClick (PokemonVoteCast { pokemonNumber = pokemonNumber, vote = stars })
        , title <| currentUserName ++ ": " ++ toString stars
        ]
        []


voteWidget : TeamRating -> Int -> String -> Html Msg
voteWidget currentUserRating pokemonNumber currentUserName =
    let
        userVote =
            { pokemonNumber = pokemonNumber
            , vote = 0
            }

        rating =
            List.head currentUserRating
                |> Maybe.map .rating
                |> Maybe.withDefault 0
    in
        span [ class "voting-node" ] <|
            List.map
                (voteWidgetStar pokemonNumber currentUserName rating)
                (List.range 1 maxStars)


noVoteWidgetElement : Html Msg
noVoteWidgetElement =
    text ""


ratingNode : Maybe Int -> UserRating -> Html Msg
ratingNode highlightedUserId rating =
    let
        star =
            span
                [ classList
                    [ ( "star", True )
                    , ( "fa-star", True )
                    , ( "fa", True )
                    ]
                ]
                []

        userTitle =
            rating.userName ++ ": " ++ toString rating.rating
    in
        span
            [ title userTitle
            , attribute "data-voter" (toString rating.id)
            , classList
                [ ( "highlight", highlightedUserId == Just rating.id )
                ]
            , style [ ( "color", rating.color ) ]
            , onClick (UserHighlightClicked rating.id)
            ]
        <|
            List.repeat rating.rating star


ratingWidget : TeamRating -> Html Msg -> Maybe Int -> Html Msg
ratingWidget otherUsersRating voteWidgetElement highlightedUserId =
    let
        ratingNodes =
            List.map (ratingNode highlightedUserId) otherUsersRating
    in
        div
            [ class "rating-nodes"
            ]
        <|
            ratingNodes
                ++ [ voteWidgetElement ]



{- in: a list of user data with ratings array.
   out: a list of user data with rating element (integer) for the specified pokemon.
-}


extractOnePokemonFromRatings : RemoteTeamRatings -> Pokemon -> TeamRating
extractOnePokemonFromRatings ratings pokemon =
    case ratings of
        Success actualRatings ->
            List.map
                (\r ->
                    { id = r.id
                    , userName = r.userName
                    , email = r.email
                    , active = r.active
                    , admin = r.admin
                    , color = r.color
                    , rating =
                        String.slice pokemon.number (pokemon.number + 1) r.ratings
                            |> String.toInt
                            |> Result.withDefault 0
                    }
                )
                actualRatings

        _ ->
            []


variantLink : String -> String -> PokemonVariant -> Html Msg
variantLink pokemonName description variant =
    let
        title =
            if String.length variant.vname > 0 then
                pokemonName ++ " (" ++ variant.vname ++ ")"
            else
                pokemonName

        imageUrl =
            imageDir ++ variant.image

        thumbnailUrl =
            thumbnailDir ++ variant.image
    in
        pokemonImg thumbnailUrl variant.vname
            |> linkToLightbox imageUrl title description


variantLinks : String -> String -> List PokemonVariant -> List (Html Msg)
variantLinks pokemonName description variants =
    List.map (variantLink pokemonName description) variants


pokemonTile : Route -> Bool -> Winner -> RemoteTeamRatings -> User -> Maybe Int -> Pokemon -> Html Msg
pokemonTile currentRoute isLocked winner ratings currentUser highlightedUserId pokemon =
    let
        isWinner =
            winner
                |> Maybe.map .number
                |> Maybe.map ((==) pokemon.number)
                |> Maybe.withDefault False

        leftMargin =
            toString (-120 * (pokemon.currentVariant - 1)) ++ "px"

        hash =
            createBrowsePath pokemon.generation pokemon.letter

        generationElement : Int -> List (Html Msg)
        generationElement gen =
            case currentRoute of
                Search _ ->
                    [ a
                        [ href hash
                        , classList [ ( "button", True ) ]
                        ]
                        [ text (romanNumeral gen)
                        ]
                    , text noBreakingSpace
                    ]

                _ ->
                    [ text "" ]

        teamRating =
            extractOnePokemonFromRatings ratings pokemon

        formattedRating =
            if isLocked then
                [ ratingWidget teamRating noVoteWidgetElement highlightedUserId ]
            else
                let
                    ( currentUserRating, otherUsersRating ) =
                        extractOneUserFromRating teamRating currentUser

                    voteWidgetElement =
                        case currentUser of
                            Nothing ->
                                text ""

                            Just actualUserName ->
                                voteWidget currentUserRating pokemon.number actualUserName
                in
                    [ ratingWidget otherUsersRating voteWidgetElement highlightedUserId ]
    in
        div
            [ classList
                [ ( "poketile", True )
                , ( "winner", isWinner )
                ]
            ]
        <|
            [ p []
                [ span [] <|
                    generationElement pokemon.generation
                        ++ [ toString pokemon.number |> text ]
                , text pokemon.name |> linkTo pokemon.url
                ]
            , div [ class "pokemon-image-strip-box" ]
                [ div
                    [ classList
                        [ ( "left-arrow", List.length pokemon.variants > 1 )
                        ]
                    , onClick (VariantChanged pokemon.number Prev)
                    ]
                    []
                , div [ class "pokemon-image-box" ]
                    [ span
                        [ class "pokemon-image-strip"
                        , style [ ( "margin-left", leftMargin ) ]
                        , List.length pokemon.variants
                            |> toString
                            |> attribute "data-variants"
                        ]
                      <|
                        variantLinks pokemon.name pokemon.description pokemon.variants
                    ]
                , div
                    [ classList
                        [ ( "right-arrow", List.length pokemon.variants > 1 )
                        ]
                    , onClick (VariantChanged pokemon.number Next)
                    ]
                    []
                ]
            ]
                ++ (case ratings of
                        Success _ ->
                            formattedRating

                        Failure _ ->
                            [ loadingErrorIcon ]

                        _ ->
                            [ loadingBusyIcon ]
                   )


pokemonTiles : Route -> Maybe Page -> List Pokemon -> RemoteTeamRatings -> User -> Maybe Int -> List (Html Msg)
pokemonTiles currentRoute currentPage pokelist ratings currentUser highlightedUserId =
    let
        winner =
            getWinner currentPage

        isLocked =
            isPageLocked currentRoute currentPage
    in
        List.map (pokemonTile currentRoute isLocked winner ratings currentUser highlightedUserId) pokelist


getDateTitle : String -> String
getDateTitle startDate =
    Date.fromString startDate
        |> Result.map (Date.Extra.toFormattedString dateTemplate)
        |> Result.map ((++) "Sprint start: ")
        |> Result.withDefault ""


dateTitle : Maybe Page -> Html Msg
dateTitle currentPage =
    let
        startDate =
            currentPage
                |> Maybe.andThen .startDate
                |> Maybe.withDefault ""
    in
        h2 [ class "date-heading" ] [ getDateTitle startDate |> text ]


pokemonCanvas : ApplicationState -> Html Msg
pokemonCanvas state =
    let
        currentPage : Maybe Page
        currentPage =
            getCurrentPage state.pages state.subPage

        pokeList =
            case state.currentRoute of
                Search _ ->
                    searchPokedexIfReady state.pokedex state.query

                Browse _ _ ->
                    filterPokedexIfReady state.pokedex state.subPage

                Default ->
                    Nothing

        canvasElements : List (Html Msg)
        canvasElements =
            pokeList
                |> Maybe.map
                    (\list ->
                        if List.length list == 0 then
                            emptyCanvas
                        else
                            pokemonTiles
                                state.currentRoute
                                currentPage
                                list
                                state.ratings
                                state.currentUser
                                state.highlightedUserId
                    )
                |> Maybe.withDefault
                    []
    in
        div [ class "pokecanvas" ] (dateTitle currentPage :: canvasElements)
