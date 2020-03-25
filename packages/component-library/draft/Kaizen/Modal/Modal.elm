module Kaizen.Modal.Modal exposing
    ( Config
    , ConfirmationType(..)
    , InputEditType(..)
    , ModalMsg
    , ModalState
    , Status(..)
    , confirmation
    , defaultFocusableId
    , firstFocusableId
    , forceOpen
    , generic
    , initialState
    , inputEdit
    , lastFocusableId
    , modalState
    , onUpdate
    , setDefaultFocusableId
    , subscriptions
    , trigger
    , update
    , view
    )

import Browser.Dom as BrowserDom
import Browser.Events as BrowserEvents
import CssModules exposing (css)
import Html exposing (Html, div, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Html.Lazy exposing (lazy)
import Kaizen.Events.Events as KaizenEvents
import Kaizen.Form.TextField.TextField as TextField
import Kaizen.Modal.Presets.ConfirmationModal as ConfirmationModal
import Kaizen.Modal.Presets.InputEditModal as InputEditModal
import Kaizen.Modal.Primitives.Constants as Constants
import Kaizen.Modal.Primitives.GenericModal as GenericModal
import Task
import Time as Time


type Config msg
    = Config (Configuration msg)


type ModalState msg
    = ModalState State


type AnimatingStep
    = Animating
    | NotAnimating


type Status
    = Closed
    | Open


type ModalMsg
    = Update
    | RunModal Time.Posix
    | FocusFirstFocusableElement (Result BrowserDom.Error ())
    | FocusLastFocusableElement (Result BrowserDom.Error ())
    | FirstFocusableElementFocused
    | LastFocusableElementFocused
    | DefaultFocusableElementFocused (Result BrowserDom.Error ())
    | ClearFocusedFocusable
    | ShiftKeydown
    | ShiftKeyup
    | FirstFocusableShiftTabbed
    | LastFocusableTabbed


type alias Configuration msg =
    { variant : Variant msg
    , onUpdate : Maybe (ModalMsg -> msg)
    , state : ModalState msg
    }


type alias State =
    ( State_, ModalData )


type State_
    = Opening_
    | Open_
    | Closing_
    | Closed_


type Duration
    = Instant
    | Immediate
    | Rapid
    | Fast


type ConfirmationType
    = Informative
    | Positive
    | Negative
    | Cautionary


type InputEditType
    = InputPositive
    | InputNegative


type FirstFocusableId
    = FirstFocusableId String


type LastFocusableId
    = LastFocusableId String


type DefaultFocusableId
    = DefaultFocusableId String


type FocusedFocusable
    = FirstFocusable
    | LastFocusable
    | NoFocus


type ModalStep
    = NotRunning
    | Running


type alias ConfirmationConfig msg =
    { title : String
    , bodySubtext : Maybe (List (Html msg))
    , onDismiss : Maybe msg
    , onConfirm : Maybe msg
    , confirmLabel : String
    , dismissLabel : String
    , onConfirmDisabled : Bool
    }


type alias InputEditConfig msg =
    { title : String
    , instructiveText : Maybe String
    , textFieldConfigs : List (TextField.Config msg)
    , onDismiss : Maybe msg
    , onConfirm : Maybe msg
    , confirmLabel : String
    , dismissLabel : String
    }


type alias ModalData =
    { duration : Duration
    , firstFocusableId : FirstFocusableId
    , lastFocusableId : LastFocusableId
    , defaultFocusableId : DefaultFocusableId
    , modalStep : ModalStep
    , startTime : Time.Posix
    , animatingStep : AnimatingStep
    , focusedFocusable : FocusedFocusable
    , shiftKeydown : Bool
    }


type alias Timing =
    { startedAt : Time.Posix
    , dt : Time.Posix
    }


subscriptions : ModalState msg -> Sub ModalMsg
subscriptions ms =
    let
        shiftKey =
            if isShiftKeydown ms then
                BrowserEvents.onKeyUp (KaizenEvents.isShift ShiftKeyup)

            else
                BrowserEvents.onKeyDown (KaizenEvents.isShift ShiftKeydown)

        keydownEscape =
            BrowserEvents.onKeyDown (KaizenEvents.isEscape Update)

        keySubscriptions =
            if isOpen ms then
                [ keydownEscape, shiftKey ]

            else
                []

        runModal =
            if isRunning ms then
                BrowserEvents.onAnimationFrame RunModal

            else
                Sub.none
    in
    Sub.batch ([ runModal ] ++ keySubscriptions)


view : Config msg -> Html msg
view c =
    let
        (Config config) =
            c

        ( mState, modalData ) =
            getState config.state
    in
    case ( mState, modalData.animatingStep ) of
        ( Closed_, NotAnimating ) ->
            text ""

        _ ->
            lazy viewContent c


viewContent : Config msg -> Html msg
viewContent (Config config) =
    let
        updateModal onUpdateMsg =
            onClick (onUpdateMsg Update)

        genericModalConfig =
            GenericModal.default

        ( mState, modalData ) =
            getState config.state

        genericModalEvents =
            List.filterMap identity
                [ Maybe.map updateModal config.onUpdate
                ]

        resolveAnimationStyles =
            case mState of
                Opening_ ->
                    [ ( .animatingElmEnter, True ) ]

                Closing_ ->
                    [ ( .animatingElmExit, True ) ]

                _ ->
                    []

        resolveVisibilityStyles =
            case config.state of
                ModalState ( Opening_, _ ) ->
                    [ ( .elmUnscrollable, True ) ]

                ModalState ( Closed_, _ ) ->
                    [ ( .hide, True ) ]

                _ ->
                    []
    in
    div
        ([ styles.classList resolveAnimationStyles ] ++ [ styles.classList resolveVisibilityStyles ])
        [ div
            ([ styles.classList
                [ ( .backdropLayer, True )
                ]
             ]
                ++ [ style "animation-duration" <| (mapDuration modalData.duration |> String.fromFloat |> (\duration -> duration ++ "ms")) ]
            )
            []
        , case config.variant of
            Generic content size ->
                GenericModal.view (GenericModal.Custom size)
                    content
                    (genericModalConfig |> GenericModal.events genericModalEvents)

            Confirmation confirmationType configs ->
                let
                    withOnDismiss confirmationConfig =
                        case configs.onDismiss of
                            Just dismissMsg ->
                                ConfirmationModal.onDismiss dismissMsg confirmationConfig

                            Nothing ->
                                case config.onUpdate of
                                    Just updateMsg ->
                                        ConfirmationModal.onDismiss (updateMsg Update) confirmationConfig

                                    Nothing ->
                                        confirmationConfig

                    withOnConfirm confirmationConfig =
                        case configs.onConfirm of
                            Just confirmMsg ->
                                ConfirmationModal.onConfirm confirmMsg confirmationConfig

                            Nothing ->
                                confirmationConfig

                    withOnConfirmDisabled confirmationConfig =
                        if configs.onConfirmDisabled then
                            ConfirmationModal.onConfirmDisabled True confirmationConfig

                        else
                            ConfirmationModal.onConfirmDisabled False confirmationConfig

                    withBodySubtext confirmationConfig =
                        case configs.bodySubtext of
                            Just subtext ->
                                ConfirmationModal.bodySubtext subtext confirmationConfig

                            Nothing ->
                                confirmationConfig

                    withFocusableIds confirmationConfig =
                        ConfirmationModal.headerDismissId (firstFocusableIdToString modalData.firstFocusableId) confirmationConfig
                            |> ConfirmationModal.confirmId (lastFocusableIdToString modalData.lastFocusableId)

                    withFocusLockAttribs confirmationConfig =
                        case config.onUpdate of
                            Just updateMsg ->
                                let
                                    withHeaderDismissPreventKeydownOn conConfig =
                                        if isShiftKeydown config.state && firstFocusableFocused config.state then
                                            ConfirmationModal.onPreventHeaderDismissKeydown [ KaizenEvents.isTab (updateMsg FirstFocusableShiftTabbed) ] conConfig

                                        else
                                            conConfig

                                    withConfirmPreventKeydownOn conConfig =
                                        if not <| isShiftKeydown config.state && lastFocusableFocused config.state then
                                            ConfirmationModal.confirmPreventKeydownOn [ KaizenEvents.isTab (updateMsg LastFocusableTabbed) ] conConfig

                                        else
                                            conConfig
                                in
                                ConfirmationModal.onHeaderDismissFocus (updateMsg FirstFocusableElementFocused) confirmationConfig
                                    |> ConfirmationModal.onConfirmFocus (updateMsg LastFocusableElementFocused)
                                    |> ConfirmationModal.onConfirmBlur (updateMsg ClearFocusedFocusable)
                                    |> ConfirmationModal.onHeaderDismissBlur (updateMsg ClearFocusedFocusable)
                                    |> withHeaderDismissPreventKeydownOn
                                    |> withConfirmPreventKeydownOn

                            Nothing ->
                                confirmationConfig

                    commonConfirmationConfig confirmationConfig =
                        withOnDismiss confirmationConfig
                            |> withOnConfirm
                            |> withOnConfirmDisabled
                            |> withBodySubtext
                            |> withFocusableIds
                            |> withFocusLockAttribs
                            |> ConfirmationModal.confirmLabel configs.confirmLabel
                            |> ConfirmationModal.dismissLabel configs.dismissLabel
                            |> ConfirmationModal.title configs.title
                in
                case confirmationType of
                    Informative ->
                        GenericModal.view GenericModal.Default
                            [ ConfirmationModal.view
                                (ConfirmationModal.informative
                                    |> commonConfirmationConfig
                                )
                            ]
                            (genericModalConfig |> GenericModal.events genericModalEvents)

                    Positive ->
                        GenericModal.view GenericModal.Default
                            [ ConfirmationModal.view
                                (ConfirmationModal.positive
                                    |> commonConfirmationConfig
                                )
                            ]
                            (genericModalConfig |> GenericModal.events genericModalEvents)

                    Negative ->
                        GenericModal.view GenericModal.Default
                            [ ConfirmationModal.view
                                (ConfirmationModal.negative
                                    |> commonConfirmationConfig
                                )
                            ]
                            (genericModalConfig |> GenericModal.events genericModalEvents)

                    Cautionary ->
                        GenericModal.view GenericModal.Default
                            [ ConfirmationModal.view
                                (ConfirmationModal.cautionary
                                    |> commonConfirmationConfig
                                )
                            ]
                            (genericModalConfig |> GenericModal.events genericModalEvents)

            InputEdit inputEditType configs ->
                let
                    withOnDismiss inputEditConfig =
                        case configs.onDismiss of
                            Just dismissMsg ->
                                InputEditModal.onDismiss dismissMsg inputEditConfig

                            Nothing ->
                                case config.onUpdate of
                                    Just updateMsg ->
                                        InputEditModal.onDismiss (updateMsg Update) inputEditConfig

                                    Nothing ->
                                        inputEditConfig

                    withOnConfirm inputEditConfig =
                        case configs.onConfirm of
                            Just confirmMsg ->
                                InputEditModal.onConfirm confirmMsg inputEditConfig

                            Nothing ->
                                inputEditConfig

                    withFocusableIds inputEditConfig =
                        InputEditModal.headerDismissId (firstFocusableIdToString modalData.firstFocusableId) inputEditConfig
                            |> InputEditModal.confirmId (lastFocusableIdToString modalData.lastFocusableId)

                    withFocusLockAttribs inputEditConfig =
                        case config.onUpdate of
                            Just updateMsg ->
                                let
                                    withHeaderDismissPreventKeydownOn inputEConfig =
                                        if isShiftKeydown config.state && firstFocusableFocused config.state then
                                            InputEditModal.onPreventHeaderDismissKeydown [ KaizenEvents.isTab (updateMsg FirstFocusableShiftTabbed) ] inputEConfig

                                        else
                                            inputEConfig

                                    withConfirmPreventKeydownOn inputEConfig =
                                        if not <| isShiftKeydown config.state && lastFocusableFocused config.state then
                                            InputEditModal.confirmPreventKeydownOn [ KaizenEvents.isTab (updateMsg LastFocusableTabbed) ] inputEConfig

                                        else
                                            inputEConfig
                                in
                                InputEditModal.onHeaderDismissFocus (updateMsg FirstFocusableElementFocused) inputEditConfig
                                    |> InputEditModal.onConfirmFocus (updateMsg LastFocusableElementFocused)
                                    |> InputEditModal.onConfirmBlur (updateMsg ClearFocusedFocusable)
                                    |> InputEditModal.onHeaderDismissBlur (updateMsg ClearFocusedFocusable)
                                    |> withHeaderDismissPreventKeydownOn
                                    |> withConfirmPreventKeydownOn

                            Nothing ->
                                inputEditConfig

                    withInstructiveText inputEditConfig =
                        case configs.instructiveText of
                            Just instructiveText ->
                                InputEditModal.instructiveText instructiveText inputEditConfig

                            Nothing ->
                                inputEditConfig

                    commonInputEditConfig inputEditConfig =
                        withOnDismiss inputEditConfig
                            |> withOnConfirm
                            |> withFocusableIds
                            |> withFocusLockAttribs
                            |> InputEditModal.confirmLabel configs.confirmLabel
                            |> InputEditModal.dismissLabel configs.dismissLabel
                            |> InputEditModal.title configs.title
                            |> InputEditModal.textFieldConfigs configs.textFieldConfigs
                in
                case inputEditType of
                    InputPositive ->
                        GenericModal.view GenericModal.Default
                            [ InputEditModal.view
                                (InputEditModal.positive
                                    |> commonInputEditConfig
                                    |> withInstructiveText
                                )
                            ]
                            (genericModalConfig |> GenericModal.events genericModalEvents)

                    InputNegative ->
                        GenericModal.view GenericModal.Default
                            [ InputEditModal.view
                                (InputEditModal.negative
                                    |> commonInputEditConfig
                                    |> withInstructiveText
                                )
                            ]
                            (genericModalConfig |> GenericModal.events genericModalEvents)
        ]


defaults : Configuration msg
defaults =
    { variant = Generic [ text "" ] ( 600, 456 )
    , onUpdate = Nothing
    , state = initialState
    }


{-| An initial state for the modal update cycle.

    If the modal is being removed from the view dynamically it can be discarded when modal is closed
    and initialState used again later when next rendering the modal.

-}
initialState : ModalState msg
initialState =
    ModalState
        ( Closed_
        , { duration = Fast
          , firstFocusableId = firstFocusableId Constants.firstFocusableId
          , lastFocusableId = lastFocusableId Constants.lastFocusableId
          , defaultFocusableId = defaultFocusableId Constants.defaultFocusableId
          , modalStep = NotRunning
          , startTime = Time.millisToPosix 0
          , animatingStep = NotAnimating
          , focusedFocusable = NoFocus
          , shiftKeydown = False
          }
        )


setDefaultFocusableId : DefaultFocusableId -> ModalState msg -> ModalState msg
setDefaultFocusableId defaultId (ModalState ( state, modalData )) =
    ModalState ( state, { modalData | defaultFocusableId = defaultId } )


styles =
    css "@kaizen/component-library/draft/Kaizen/Modal/Primitives/GenericModal.scss"
        { backdropLayer = "backdropLayer"
        , animatingElmEnter = "animatingElmEnter"
        , elmUnscrollable = "elmUnscrollable"
        , animatingElmExit = "animatingElmExit"
        , elmGenericModal = "elmGenericModal"
        , hide = "hide"
        }



-- INTERNAL HELPERS


mapDuration : Duration -> Float
mapDuration duration =
    case duration of
        Instant ->
            0

        Immediate ->
            100

        Rapid ->
            200

        Fast ->
            300


isOpen : ModalState msg -> Bool
isOpen (ModalState state) =
    case state of
        ( Open_, _ ) ->
            True

        _ ->
            False


isRunning : ModalState msg -> Bool
isRunning (ModalState ( _, mData )) =
    mData.modalStep == Running


isShiftKeydown : ModalState msg -> Bool
isShiftKeydown (ModalState ( _, mData )) =
    mData.shiftKeydown


firstFocusableFocused : ModalState msg -> Bool
firstFocusableFocused (ModalState ( _, mData )) =
    mData.focusedFocusable == FirstFocusable


lastFocusableFocused : ModalState msg -> Bool
lastFocusableFocused (ModalState ( _, mData )) =
    mData.focusedFocusable == LastFocusable


firstFocusableIdToString : FirstFocusableId -> String
firstFocusableIdToString (FirstFocusableId id_) =
    id_


lastFocusableIdToString : LastFocusableId -> String
lastFocusableIdToString (LastFocusableId id_) =
    id_


defaultFocusableIdToString : DefaultFocusableId -> String
defaultFocusableIdToString (DefaultFocusableId id_) =
    id_


updateModalDataFromState : (ModalData -> ModalData) -> ModalState msg -> ModalState msg
updateModalDataFromState f (ModalState ( mState, mData )) =
    ModalState ( mState, f mData )


resolveCmdsFromState : ModalState msg -> Cmd ModalMsg
resolveCmdsFromState (ModalState ( ms, mData )) =
    case mData.modalStep of
        NotRunning ->
            case ( ms, mData.animatingStep ) of
                ( Open_, NotAnimating ) ->
                    Task.attempt DefaultFocusableElementFocused <| BrowserDom.focus (defaultFocusableIdToString mData.defaultFocusableId)

                _ ->
                    Cmd.none

        Running ->
            Cmd.none


resolveStatusFromState : ModalState msg -> Maybe Status
resolveStatusFromState (ModalState ( ms, mData )) =
    case mData.modalStep of
        NotRunning ->
            case ms of
                Open_ ->
                    Just Open

                Closed_ ->
                    Just Closed

                _ ->
                    Nothing

        Running ->
            Nothing



-- HELPERS


{-| For when you want to start the modal off open without being triggered open.

    This is not recommended as modals should be triggered by an intentional user action

-}
forceOpen : ModalState msg -> ModalState msg
forceOpen (ModalState ( _, mData )) =
    ModalState ( Open_, { mData | modalStep = Running, animatingStep = Animating } )


firstFocusableId : String -> FirstFocusableId
firstFocusableId id =
    FirstFocusableId id


lastFocusableId : String -> LastFocusableId
lastFocusableId id =
    LastFocusableId id


defaultFocusableId : String -> DefaultFocusableId
defaultFocusableId id =
    DefaultFocusableId id



-- VARIANTS


type Variant msg
    = Generic (List (Html msg)) ( Float, Float )
    | Confirmation ConfirmationType (ConfirmationConfig msg)
    | InputEdit InputEditType (InputEditConfig msg)


generic : List (Html msg) -> ( Float, Float ) -> Config msg
generic v size =
    Config { defaults | variant = Generic v size }


confirmation : ConfirmationType -> ConfirmationConfig msg -> Config msg
confirmation confirmationType confirmationConfig =
    Config
        { defaults
            | variant = Confirmation confirmationType confirmationConfig
        }


inputEdit : InputEditType -> InputEditConfig msg -> Config msg
inputEdit inputEditType inputEditConfig =
    Config
        { defaults
            | variant = InputEdit inputEditType inputEditConfig
        }



-- MODIFIERS


onUpdate : (ModalMsg -> msg) -> Config msg -> Config msg
onUpdate msg (Config config) =
    Config { config | onUpdate = Just msg }


modalState : ModalState msg -> Config msg -> Config msg
modalState msg (Config config) =
    Config { config | state = msg }



--UPDATE


trigger : ModalState msg -> ModalState msg
trigger (ModalState ( state, mData )) =
    ModalState ( state, { mData | modalStep = Running } )


update : ModalState msg -> ModalMsg -> ( ModalState msg, Cmd ModalMsg, Maybe Status )
update ms modalMsg =
    let
        (ModalState ( _, mData )) =
            ms
    in
    case modalMsg of
        Update ->
            ( updateModalDataFromState (\md -> { md | modalStep = Running }) ms, Cmd.none, Nothing )

        RunModal currentTimePosix ->
            case mData.modalStep of
                Running ->
                    let
                        newRunningState =
                            updateRunningState ms currentTimePosix
                    in
                    ( newRunningState, resolveCmdsFromState newRunningState, resolveStatusFromState newRunningState )

                NotRunning ->
                    ( ms, Cmd.none, Nothing )

        FirstFocusableElementFocused ->
            ( updateModalDataFromState (\md -> { md | focusedFocusable = FirstFocusable }) ms, Cmd.none, Nothing )

        LastFocusableElementFocused ->
            ( updateModalDataFromState (\md -> { md | focusedFocusable = LastFocusable }) ms, Cmd.none, Nothing )

        ClearFocusedFocusable ->
            ( updateModalDataFromState (\md -> { md | focusedFocusable = NoFocus }) ms, Cmd.none, Nothing )

        FocusFirstFocusableElement focusResult ->
            case focusResult of
                Ok () ->
                    ( ms, Cmd.none, Nothing )

                Err _ ->
                    ( ms, Cmd.none, Nothing )

        FocusLastFocusableElement focusResult ->
            case focusResult of
                Ok () ->
                    ( ms, Cmd.none, Nothing )

                Err _ ->
                    ( ms, Cmd.none, Nothing )

        DefaultFocusableElementFocused focusResult ->
            case focusResult of
                Ok () ->
                    ( ms, Cmd.none, Nothing )

                -- Fallback to the last focusable element if the default focusable element is not found
                -- This will work for when the last and default focusable element ids are the same e.g. Confirmation variants
                Err _ ->
                    ( ms
                    , Task.attempt FocusLastFocusableElement (BrowserDom.focus <| lastFocusableIdToString mData.lastFocusableId)
                    , Nothing
                    )

        ShiftKeydown ->
            ( updateModalDataFromState (\md -> { md | shiftKeydown = True }) ms, Cmd.none, Nothing )

        ShiftKeyup ->
            ( updateModalDataFromState (\md -> { md | shiftKeydown = False }) ms, Cmd.none, Nothing )

        FirstFocusableShiftTabbed ->
            ( ms
            , Task.attempt FocusLastFocusableElement (BrowserDom.focus <| lastFocusableIdToString mData.lastFocusableId)
            , Nothing
            )

        LastFocusableTabbed ->
            ( ms
            , Task.attempt FocusFirstFocusableElement (BrowserDom.focus <| firstFocusableIdToString mData.firstFocusableId)
            , Nothing
            )


updateRunningState : ModalState msg -> Time.Posix -> ModalState msg
updateRunningState ((ModalState ( state, mData )) as ms) now =
    let
        deltaTime =
            Time.posixToMillis now - Time.posixToMillis mData.startTime
    in
    case state of
        Open_ ->
            let
                resolveState =
                    case mData.animatingStep of
                        Animating ->
                            ModalState ( Open_, { mData | animatingStep = NotAnimating, modalStep = NotRunning } )

                        NotAnimating ->
                            ModalState ( Closing_, { mData | animatingStep = Animating, startTime = now } )
            in
            resolveState

        -- progress is always Animating when Opening
        Opening_ ->
            if deltaTime < round (mapDuration mData.duration) then
                ms

            else
                ModalState ( Open_, mData )

        -- progress is always Animating when Closing
        Closing_ ->
            if deltaTime < round (mapDuration mData.duration) then
                ms

            else
                ModalState ( Closed_, mData )

        Closed_ ->
            let
                resolveState =
                    case mData.animatingStep of
                        Animating ->
                            ModalState ( Closed_, { mData | animatingStep = NotAnimating, modalStep = NotRunning, startTime = Time.millisToPosix 0 } )

                        NotAnimating ->
                            ModalState ( Opening_, { mData | animatingStep = Animating, startTime = now } )
            in
            resolveState


getState : ModalState msg -> State
getState (ModalState state) =
    state
