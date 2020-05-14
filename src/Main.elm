module Main exposing (..)

import Browser
import Css exposing (..)
import Debug
import Html.Styled as H exposing (Html)
import Html.Styled.Attributes as A exposing (..)
import Html.Styled.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder, at, bool, index, map, map4, oneOf, string)


main =
    Browser.document
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type alias Model =
    { status : AppStatus
    , url : String
    }


type AppStatus
    = Initial
    | Failure Http.Error
    | Success Response


type alias Definition =
    { word : String
    , fl : String
    , def : String
    , isOffensive : Bool
    }


type alias Alternatives =
    { first : String
    , second : String
    , third : String
    , fourth : String
    }


theme : { secondary : Color, primary : Color }
theme =
    { primary = hex "98d3e6"
    , secondary = rgb 250 240 230
    }


paragraphFont : Style
paragraphFont =
    Css.batch
        [ fontFamilies [ "Palatino Linotype", "Georgia", "serif" ] ]


responseDiv : Style
responseDiv =
    Css.batch
        [ paragraphFont
        , display block
        , Css.width (pct 100)
        , padding2 (px 50) (pct 10)
        , marginTop (vh 10)
        , lineHeight (px 20)
        , borderTop3 (px 10) solid (rgb 255 255 255)
        , boxSizing borderBox
        ]


errorMsg : Style
errorMsg =
    Css.batch
        [ paragraphFont
        , marginTop (vh 10)
        ]


sideNote : Style
sideNote =
    Css.batch
        [ color (rgb 100 100 100)
        , margin2 (px 20) zero
        ]


type Response
    = Def Definition
    | Alt Alternatives


init : () -> ( Model, Cmd Msg )
init _ =
    ( { status = Initial, url = "" }
    , Cmd.none
    )


type Msg
    = Search
    | NewContent String
    | GotDef (Result Http.Error Response)



-- | GotProgress Http.Progress


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Search ->
            ( model
            , Http.request
                { method = "GET"
                , headers = []
                , url = model.url
                , body = Http.emptyBody
                , expect = Http.expectJson GotDef respDecoder
                , timeout = Just 2000.0
                , tracker = Nothing

                -- , tracker = Just "word"
                }
            )

        NewContent s ->
            let
                root =
                    "https://www.dictionaryapi.com/api/v3/references/learners/json/"

                key =
                    "24375962-78c5-4fbc-a585-b37ed4088caf"

                request : String -> String
                request word =
                    root ++ word ++ "?key=" ++ key
            in
            ( { model | url = request s }, Cmd.none )

        GotDef result ->
            case result of
                Ok def ->
                    ( { model | status = Success def }, Cmd.none )

                Err error ->
                    ( { model | status = Failure error }, Cmd.none )



-- GotProgress p ->
--     case p of
--         Http.Sending s ->
--             if Http.fractionSent s /= 0.0 then
--                 (model, Http.cancel "word")
--             else
--                 (model, Cmd.none)
--         Http.Receiving _->
--             (model, Cmd.none)
-- newReq : String -> Model -> List String


defDecoder : Decoder Response
defDecoder =
    Decode.map Def
        (map4 Definition
            (index 0 (at [ "meta", "app-shortdef", "hw" ] string))
            (index 0 (at [ "meta", "app-shortdef", "fl" ] string))
            (index 0 (at [ "shortdef" ] (index 0 string)))
            (index 0 (at [ "meta", "offensive" ] bool))
        )


altDecoder : Decoder Response
altDecoder =
    Decode.map Alt
        (map4 Alternatives
            (index 0 string)
            (index 1 string)
            (index 2 string)
            (index 3 string)
        )


respDecoder : Decoder Response
respDecoder =
    oneOf
        [ defDecoder
        , altDecoder
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "Elm Dictionary"
    , body =
        List.map H.toUnstyled
            [ H.div
                [ A.css
                    [ displayFlex
                    , flexDirection column
                    , Css.width (vw 50)
                    , Css.height (vh 100)
                    , justifyContent flexStart
                    , alignItems center
                    , margin2 zero auto
                    , padding2 (px 50) zero
                    , backgroundColor theme.secondary
                    ]
                ]
                [ H.h1
                    [ A.css
                        [ paragraphFont
                        , color theme.primary
                        , textAlign center
                        ]
                    ]
                    [ H.text "Elm Dictionary" ]
                , H.div
                    [ A.css
                        [ textAlign center
                        , marginTop (px 20)
                        ]
                    ]
                    [ H.input
                        [ A.type_ "text"
                        , onInput NewContent
                        , A.attribute "data-cy" "input"
                        , A.css
                            [ padding (px 5)
                            , fontSize (em 1.1)
                            ]
                        ]
                        []
                    , H.button
                        [ onClick Search
                        , A.attribute "data-cy" "submit"
                        , A.css
                            [ backgroundColor theme.primary
                            , color (rgb 90 90 90)
                            , padding (px 8)
                            , marginLeft (px 5)
                            , fontSize (em 0.9)
                            , border (px 0)
                            , boxShadow3 (px 1) (px 2) (rgb 200 200 200)
                            , hover
                                [ textDecoration underline
                                , color (rgb 26 26 26)
                                ]
                            ]
                        ]
                        [ H.text "Search" ]
                    ]
                , viewResult model
                ]
            ]
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- Http.track "word" GotProgress


viewResult : Model -> Html msg
viewResult model =
    case model.status of
        Initial ->
            H.div [] [ H.text "" ]

        Success resp ->
            case resp of
                Def d ->
                    H.div [ A.css [ responseDiv ] ]
                        [ H.div
                            [ A.attribute "data-cy" "word"
                            , A.css
                                [ fontSize (em 1.1)
                                , textTransform capitalize
                                ]
                            ]
                            [ H.text d.word ]
                        , H.div
                            [ A.attribute "data-cy" "fl"
                            , A.css [ sideNote ]
                            ]
                            [ H.text d.fl ]
                        , H.div [ A.attribute "data-cy" "def" ] [ H.text d.def ]
                        , H.div [ A.attribute "data-cy" "isOffensive"
                                , A.css [ sideNote ] 
                                ] 
                                [ checkOffense d.isOffensive ]
                        ]

                Alt a ->
                    H.div [ A.css [ responseDiv ] ]
                        [ H.div [ A.css [ margin2 (px 10) zero ] ] [ H.text "Did you mean: " ]
                        , H.div [] [ H.text a.first ]
                        , H.div [] [ H.text a.second ]
                        , H.div [] [ H.text a.third ]
                        , H.div [] [ H.text a.fourth ]
                        ]

        Failure error ->
            case error of
                Http.BadBody _ ->
                    H.div [ A.attribute "data-cy" "msg", A.css [ errorMsg ] ] [ H.text "Invalid entries" ]

                Http.NetworkError ->
                    H.div [ A.attribute "data-cy" "msg" ] [ H.text "No internet connection" ]

                Http.BadStatus _ ->
                    H.div [ A.attribute "data-cy" "msg" ] [ H.text "Something's wrong with Merriam-Webster API, try later?" ]

                Http.BadUrl _ ->
                    H.div [ A.attribute "data-cy" "msg" ] [ H.text "URL invalid" ]

                Http.Timeout ->
                    H.div [ A.attribute "data-cy" "msg" ] [ H.text "Time out, try again?" ]


checkOffense : Bool -> Html msg
checkOffense b =
    if b == True then
        H.text "Offensive: true"

    else
        H.text "Offensive: false"
