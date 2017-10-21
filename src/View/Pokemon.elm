module View.Pokemon exposing (pokemonCanvas)

import List
import Maybe
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData, RemoteData(..))
import Constants exposing (maxStars)
import Helpers exposing (filterPokedex, searchPokedex, romanNumeral)
import Models exposing (..)
import Msgs exposing (Msg)


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
        ]
        [ content ]


linkToLighthouse : String -> String -> Html Msg -> Html Msg
linkToLighthouse imageUrl caption content =
    a
        [ href imageUrl
        , Html.Attributes.attribute "data-lightbox" "pokemon"
        , Html.Attributes.attribute "data-title" caption
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
            , ( "selected", rating >= stars )
            ]
        , onClick (Msgs.VoteForPokemon { pokemonNumber = pokemonNumber, vote = stars })
        , title <| currentUserName ++ ": " ++ (toString stars)
        ]
        []


voteWidget : TeamRating -> Int -> String -> Html Msg
voteWidget ownRatings pokemonNumber currentUserName =
    let
        userVote =
            { pokemonNumber = pokemonNumber
            , vote = 0
            }

        rating =
            case List.head ownRatings of
                Nothing ->
                    0

                Just ratingRecord ->
                    ratingRecord.rating
    in
        span [ class "voting-node" ] <|
            List.map
                (voteWidgetStar pokemonNumber currentUserName rating)
                (List.range 1 maxStars)


ratingNode : UserRating -> Html Msg
ratingNode rating =
    let
        star =
            span [ class "star" ] []

        userTitle =
            rating.userName ++ ": " ++ toString rating.rating
    in
        span
            [ title userTitle
            , style [ ( "color", rating.color ) ]
            ]
        <|
            List.repeat rating.rating star


ratingWidget : TeamRating -> Html Msg
ratingWidget ratings =
    div
        [ class "rating-nodes"
        ]
    <|
        List.map ratingNode ratings


extractOnePokemonFromRatings : WebData TeamRatings -> Pokemon -> TeamRating
extractOnePokemonFromRatings ratings pokemon =
    case ratings of
        Success actualRatings ->
            List.map
                (\r ->
                    { id = r.id
                    , userName = r.userName
                    , email = r.email
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


extractOneUserFromRatings : TeamRating -> CurrentUser -> ( TeamRating, TeamRating )
extractOneUserFromRatings ratings currentUser =
    case currentUser of
        Nothing ->
            ( [], ratings )

        Just simpleUserName ->
            List.partition (.userName >> (==) simpleUserName) ratings


variantLink : String -> PokemonVariant -> Html Msg
variantLink pokemonName variant =
    let
        caption =
            if String.length variant.vname > 0 then
                pokemonName ++ " (" ++ variant.vname ++ ") "
            else
                pokemonName
    in
        pokemonImg variant.image variant.vname
            |> linkToLighthouse variant.image caption


variantLinks : String -> List PokemonVariant -> List (Html Msg)
variantLinks pokemonName variants =
    List.map (variantLink pokemonName) variants


pokemonTile : ViewMode -> WebData TeamRatings -> CurrentUser -> Pokemon -> Html Msg
pokemonTile viewMode ratings currentUser pokemon =
    let
        allUserRatings =
            extractOnePokemonFromRatings ratings pokemon

        ( ownRatings, otherRatings ) =
            extractOneUserFromRatings allUserRatings currentUser

        leftMargin =
            toString (-120 * (pokemon.currentVariant - 1)) ++ "px"

        hash =
            "#" ++ (toString pokemon.generation) ++ (String.fromChar pokemon.letter)

        generationElement : Int -> List (Html Msg)
        generationElement gen =
            case viewMode of
                Browse ->
                    [ text "" ]

                Search ->
                    [ a
                        [ href hash
                        , classList [ ( "button", True ) ]
                        ]
                        [ text (romanNumeral gen)
                        ]
                    , text " " -- no-breaking space
                    ]

        actualVoteWidget =
            case currentUser of
                Nothing ->
                    unknownUserIcon

                Just actualUserName ->
                    voteWidget ownRatings pokemon.number actualUserName
    in
        div [ class "poketile" ] <|
            [ p []
                [ span [] <|
                    (generationElement pokemon.generation)
                        ++ [ text <| toString pokemon.number ]
                , linkTo pokemon.url <| text pokemon.name
                ]
            , div [ class "pokemon-image-strip-box" ]
                [ div
                    [ classList
                        [ ( "left-arrow", List.length pokemon.variants > 1 )
                        ]
                    , onClick (Msgs.ChangeVariant pokemon.number Prev)
                    ]
                    []
                , div [ class "pokemon-image-box" ]
                    [ span
                        [ class "pokemon-image-strip"
                        , style [ ( "margin-left", leftMargin ) ]
                        , List.length pokemon.variants
                            |> toString
                            |> Html.Attributes.attribute "data-variants"
                        ]
                      <|
                        variantLinks pokemon.name pokemon.variants
                    ]
                , div
                    [ classList
                        [ ( "right-arrow", List.length pokemon.variants > 1 )
                        ]
                    , onClick (Msgs.ChangeVariant pokemon.number Next)
                    ]
                    []
                ]
            ]
                ++ case ratings of
                    Success _ ->
                        [ ratingWidget otherRatings
                        , actualVoteWidget
                        ]

                    Failure _ ->
                        [ loadingErrorIcon ]

                    _ ->
                        [ loadingBusyIcon ]


pokemonTiles : ViewMode -> List Pokemon -> WebData TeamRatings -> CurrentUser -> List (Html Msg)
pokemonTiles viewMode pokelist ratings currentUser =
    List.map (pokemonTile viewMode ratings currentUser) pokelist


pokemonCanvas : ApplicationState -> Html Msg
pokemonCanvas state =
    let
        pokeList =
            case state.viewMode of
                Browse ->
                    filterPokedex state.pokedex state.generation state.letter

                Search ->
                    searchPokedex state.pokedex state.query
    in
        div [ class "pokecanvas" ] <| pokemonTiles state.viewMode pokeList state.ratings state.user
