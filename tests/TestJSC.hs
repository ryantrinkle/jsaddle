{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
-----------------------------------------------------------------------------
--
-- Module      :  TestJSC
-- Copyright   :  (c) Hamish Mackenzie
-- License     :  MIT
--
-- Maintainer  :  Hamish Mackenzie <Hamish.K.Mackenzie@googlemail.com>
--
-- |
--
-----------------------------------------------------------------------------

module Main (
    main
) where

import Prelude hiding((!!))
import Graphics.UI.Gtk
       (Window, widgetDestroy, postGUIAsync, postGUISync, widgetShowAll,
        mainGUI, mainQuit, onDestroy, containerAdd, scrolledWindowNew,
        windowSetPosition, windowSetDefaultSize, timeoutAddFull, windowNew,
        initGUI)
import Control.Concurrent
       (tryTakeMVar, forkIO, newMVar, putMVar, takeMVar, newEmptyMVar,
        yield)
import System.Glib.MainLoop (priorityHigh)
import Graphics.UI.Gtk.General.Enums (WindowPosition(..))
import Graphics.UI.Gtk.WebKit.WebView
       (webViewGetMainFrame, webViewNew)
import System.IO.Unsafe (unsafePerformIO)
import Control.Monad.Trans.Reader (runReaderT)
import Graphics.UI.Gtk.WebKit.JavaScriptCore.JSBase (JSContextRef)
import Graphics.UI.Gtk.WebKit.JavaScriptCore.WebFrame
       (webFrameGetGlobalContext)
import Language.Javascript.JSC
import Data.Text (Text)
import qualified Data.Text as T
import Control.Applicative
import Control.Monad.IO.Class (MonadIO(..))
import Control.Monad (when)
import System.Log.Logger (debugM)
import Control.Lens.Getter ((^.))

data TestState = TestState { jsContext :: JSContextRef, window :: Window }

state = unsafePerformIO $ newMVar Nothing
done = unsafePerformIO $ newEmptyMVar

-- >>> testJSC $ ((global ^. js "console" . js "log") # ["Hello"])
testJSC :: MakeValueRef val => JSC val -> IO Text
testJSC = testJSC' False

-- >>> showJSC $ eval "document.body.innerHTML = 'Test'"
showJSC :: MakeValueRef val => JSC val -> IO Text
showJSC = testJSC' True

debugLog = debugM "jsc"

testJSC' :: MakeValueRef val => Bool -> JSC val -> IO Text
testJSC' show f = do
    debugLog "taking done"
    tryTakeMVar done
    debugLog "taking state"
    mbState <- takeMVar state
    TestState {..} <- case mbState of
        Nothing -> do
            debugLog "newState"
            newState <- newEmptyMVar
            debugLog "fork"
            forkIO $ do
                debugLog "initGUI"
                initGUI
                debugLog "windowNew"
                window <- windowNew
                debugLog "timeoutAdd"
                timeoutAddFull (yield >> return True) priorityHigh 10
                windowSetDefaultSize window 900 600
                windowSetPosition window WinPosCenter
                scrollWin <- scrolledWindowNew Nothing Nothing
                webView <- webViewNew
                window `containerAdd` scrollWin
                scrollWin `containerAdd` webView
                window `onDestroy` do
                    debugLog "onDestroy"
                    tryTakeMVar state
                    debugLog "put state"
                    putMVar state Nothing
                    debugLog "mainQuit"
                    mainQuit
                    debugLog "put done"
                    putMVar done ()
                debugLog "get context"
                jsContext <- webViewGetMainFrame webView >>= webFrameGetGlobalContext
                debugLog "put initial state"
                putMVar newState TestState {..}
                debugLog "maybe show"
                when show $ widgetShowAll window
                debugLog "mainGUI"
                mainGUI
                debugLog "mainGUI exited"
            takeMVar newState
        Just s@TestState {..} -> do
            debugLog "maybe show (2)"
            when show . postGUISync $ widgetShowAll window
            return s
    x <- postGUISync $ runReaderT ((f >>= valToText)
            `catch` \ (JSException e) -> valToText e) jsContext
    debugLog "put state"
    putMVar state $ Just TestState {..}
    return x

main = do
    testJSC $ return ()
    Just TestState{..} <- takeMVar state
    postGUIAsync $ widgetDestroy window
    takeMVar done









