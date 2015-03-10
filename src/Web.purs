module Web
  ( exprToJQuery
  , Handler ()
  ) where

import Control.Monad.Eff
import qualified Control.Monad.JQuery as J
import DOM

import Data.Traversable (for, zipWithA)
import Data.Maybe
import Data.Array ((..), length)
import Data.StrMap (lookup)
import Data.Tuple
import Control.Apply ((*>))

import AST
import Evaluator

type Handler = forall eff. Expr -> Path -> Eff (dom :: DOM | eff) Unit

exprToJQuery :: forall eff. Env -> Expr -> Handler -> Eff (dom :: DOM | eff) J.JQuery
exprToJQuery env expr handler = go Start expr
  where
  addHandler :: Path -> J.JQuery -> Eff (dom :: DOM | eff) J.JQuery
  addHandler p j = do
    J.on "click" (\je _ -> J.stopImmediatePropagation je *> handler expr p) j
    J.addClass "clickable" j
  go :: (Path -> Path) -> Expr -> Eff (dom :: DOM | eff) J.JQuery
  go p expr = case expr of
    Atom (Num n)     -> makeDiv (show n) ["atom", "num"]
    Atom (Bool b)    -> makeDiv (show b) ["atom", "bool"]
    Atom (Name name) -> do
      jName <- makeDiv name ["atom", "name"]
      case lookup name env of
        Just [Tuple [] _] -> addHandler (p End) jName
        _                 -> return jName
    Binary op e1 e2 -> do
      j1 <- go (p <<< Fst) e1
      j2 <- go (p <<< Snd) e2
      binary op j1 j2 >>= addHandler (p End)
    List es -> do
      js <- zipWithA (\i e -> go (p <<< Nth i) e) (0 .. (length es - 1)) es
      list js
    SectL e op -> do
      j <- go (p <<< Fst) e
      jop <- makeDiv (show op) ["op"]
      section j jop
    SectR op e -> do
      jop <- makeDiv (show op) ["op"]
      j <- go (p <<< Fst) e
      section jop j
    Prefix op -> makeDiv ("(" ++ show op ++ ")") ["prefix", "op"]
    App func args -> do
      jFunc <- go (p <<< Fst) func
      jArgs <- zipWithA (\i e -> go (p <<< Nth i) e) (0 .. (length args - 1)) args
      app jFunc jArgs >>= addHandler (p End)

binary :: forall eff. Op -> J.JQuery -> J.JQuery -> Eff (dom :: DOM | eff) J.JQuery
binary op j1 j2 = do
  dBin <- makeDiv "" ["binary"]
  J.append j1 dBin
  dOp <- makeDiv (show op) ["op"]
  J.append dOp dBin
  J.append j2 dBin
  return dBin

section :: forall eff. J.JQuery -> J.JQuery -> Eff (dom :: DOM | eff) J.JQuery
section j1 j2 = do
  jSect <- makeDiv "" ["section"]
  open <- makeDiv "(" ["brace"]
  J.append open jSect
  J.append j1 jSect
  J.append j2 jSect
  close <- makeDiv ")" ["brace"]
  J.append close jSect
  return jSect

list :: forall eff. [J.JQuery] -> Eff (dom :: DOM | eff) J.JQuery
list js = do
  dls <- makeDiv "" ["list"]
  open <- makeDiv "[" ["brace"]
  J.append open dls
  sep js dls
  close <- makeDiv "]" ["brace"]
  J.append close dls
  return dls
  where
  sep []     dls = return unit
  sep [j]    dls = void $ J.append j dls
  sep (j:js) dls = do
    J.append j dls
    comma <- makeDiv "," ["comma"]
    J.append comma dls
    sep js dls


app :: forall eff. J.JQuery -> [J.JQuery] -> Eff (dom :: DOM | eff) J.JQuery
app jFunc jArgs = do
  dApp <- makeDiv "" ["app"]
  J.addClass "func" jFunc
  J.append jFunc dApp
  for jArgs (flip J.append dApp)
  return dApp

type Class = String

makeDiv :: forall eff. String -> [Class] -> Eff (dom :: DOM | eff) J.JQuery
makeDiv text classes = do
  d <- J.create "<div></div>"
  J.setText text d
  for classes (flip J.addClass d)
  return d
