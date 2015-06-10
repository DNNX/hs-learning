module Main where

import qualified Learning.PDDL.NonConditionalTypes        as NCT
-- import           Data.TupleSet                            (TupleSet)
-- import qualified Data.TupleSet                            as TSet
import           Environment                              as Env
import           Environment.Sokoban
import           Environment.Sokoban.PDDL
import qualified Environment.Sokoban.Samples.BigSample    as BS
import qualified Environment.Sokoban.Samples.LargeSample  as LS
import qualified Environment.Sokoban.Samples.SimpleSample as SS
import qualified Environment.Sokoban.Samples.WikiSample   as WS
import           Environment.Sokoban.SokobanDomain
import           Environment.Sokoban.SokobanView
import qualified Learning.PDDL.ConditionalKnowledge       as CK
-- import           Graph.Search.Astar                       as Astar
import           Learning
import qualified Learning.PDDL                            as PDDL
-- import qualified Learning.PDDL.EffectKnowledge            as Eff
-- import           Learning.PDDL.Experiment
import           Learning.PDDL.NonConditionalKnowledge
import           Learning.PDDL.OptimisticStrategy
-- import qualified Learning.PDDL.PreconditionKnowledge      as Pre
import           Charting
import           Planning
import           Planning.PDDL

import           Control.Monad                            (unless)
-- import           Data.Map                                 (Map)
import qualified Data.Map                                 as Map
import           Data.Set                                 ((\\))
import qualified Data.Set                                 as Set
import           System.Console.ANSI
import           System.Directory                         (removeFile)
import           System.IO.Error
import           Text.Show.Pretty


deltaKnl :: (NCT.PreKnowledge, NCT.EffKnowledge)
         -> (NCT.PreKnowledge, NCT.EffKnowledge)
         -> (NCT.Knowledge, NCT.Knowledge)
deltaKnl (pk1, ek1) (pk2, ek2) =
    ( NCT.deltaKnl (NCT.knlFromPk pk1) (NCT.knlFromPk pk2)
    , NCT.deltaKnl (NCT.knlFromEk ek1) (NCT.knlFromEk ek2)
    )

actKnl :: SokoSimStep -> (NCT.Knowledge, NCT.Knowledge)
actKnl step = (NCT.knlFromPk p, NCT.knlFromEk e) where
    domKnl = domainKnowledge $ ssKnl step
    act = lastAction step
    (p, e) = case Map.lookup (aName act) domKnl of
               Just k -> k
               Nothing -> error "ERROR"

learned :: SokoSimStep -> SokoSimStep -> (NCT.Knowledge, NCT.Knowledge)
learned prev latest = deltaKnl (actKnl prev) (actKnl latest) where
   domKnl = domainKnowledge . ssKnl
   act = lastAction latest
   actKnl s = case Map.lookup (aName act) (domKnl s) of
                Just k -> k
                Nothing -> error "ERROR message"

showWorld :: [SokoSimStep] -> IO ()
showWorld (step : _) = visualize $ ssWorld step
showWorld [] = return ()

showLearned :: [SokoSimStep] -> IO ()
showLearned (step : prev : _) =  print (Set.size (NCT.posKnown precs'))
                              >> print (Set.size (NCT.negKnown precs'))
                              >> print (Set.size (NCT.posKnown effs'))
                              >> print (Set.size (NCT.negKnown effs'))
                              >> posPrecMessage >> negPrecMessage
                              >> posEffMessage >> negEffMessage
                              >> nPosPrecMessage >> nNegPrecMessage
                              >> nPosEffMessage >> nNegEffMessage where
    (precs, effs) = learned prev step
    (precs', effs') = actKnl step
    baseMessage = "The following predicates have been proven to be "
    message set str = unless (Set.null set)
                    $ putStrLn $ baseMessage ++ str ++ ppShow set

    posPrecMessage  = message (NCT.posKnown precs) "positive preconditions: "
    negPrecMessage  = message (NCT.negKnown precs) "negative preconditions: "
    posEffMessage   = message (NCT.posKnown effs) "positive effects: "
    negEffMessage   = message (NCT.negKnown effs) "negative effects: "

    nPosPrecMessage = message (NCT.posUnknown precs) "NOT pos prec: "
    nNegPrecMessage = message (NCT.negUnknown precs) "NOT neg prec: "
    nPosEffMessage  = message (NCT.posUnknown effs) "NOT pos effs: "
    nNegEffMessage  = message (NCT.negUnknown effs) "NOT neg effs: "
showLearned _ = return ()

showAct :: [SokoSimStep] -> IO ()
showAct (step : _) = putStrLn $ "executed action " ++ show (lastAction step)
showAct _ = return ()

showBound :: [SokoSimStep] -> IO ()
showBound (step : _) = print b where
    (OptimisticStrategy (_, b)) = ssStrat step
showBound [] = return ()

writeSim :: [SokoSimStep] -> IO ()
writeSim steps =  showAct steps
               >> showWorld steps
               >> showLearned steps
               >> showBound steps
-- writeSim [] = return ()

main :: IO ()
main = do
    let bigWorld = BS.world
        s = Env.toState (fromWorld bigWorld)
        eSpec = pddlEnvSpec sokobanDomain (toProblem bigWorld)
        s' = Env.toState $ fromWorld $ move bigWorld DownDir
        t = (s, ("a", []), s')
        -- hg = head $ CK.fromTransition eSpec t
        baseHg = CK.fromTotalState eSpec (totalState s eSpec)
        ts = totalState s eSpec
        ts' = totalState s' eSpec
        succs = ts' \\ ts -- effects that were successfully applied
        hg = CK.fromEffect baseHg $ (head . Set.toList) succs
        hg' = CK.merge hg hg
    putStrLn $ ppShow (CK.size hg') ++ " : " ++ ppShow (CK.size hg)

-- main :: IO ()
-- main = do
--     catchIOError (removeFile logPath) (\_ -> return ())
--     clearScreen
--     setTitle "SOKOBAN!"
--
--     -- putStrLn (ppShow $ initialState prob)
--     _ <- runAll writeSim optStrat initKnl [ (ssEnv, ssProb)
--                                             --  , (lsEnv, lsProb)
--                                             --  , (bsEnv, bsProb)
--                                              ]
--     -- chartKnowledge hist
--     -- hist <- scientificMethod writeSim optStrat initKnl ssEnv ssProb
--     -- (knl'', world'') <- scientificMethod emptyIO optStrat knl' lsEnv lsProb
--     -- (knl''', world''') <- scientificMethod emptyIO optStrat knl'' bsEnv bsProb
--     -- putStrLn (ppShow fenv)
--     -- putStrLn (ppShow dom''')
--     -- writeFile "sokoDom.pddl" $ writeDomain dom
--     -- writeFile "sokoProb.pddl" $ writeProblem wsProb
--     return ()
--     where
--         logPath = "./log.log"
--
--         optStrat = OptimisticStrategy (Astar Nothing, Nothing)
--         -- bsWorld = BS.world
--         -- bsEnv = fromWorld bsWorld
--         -- bsProb = toProblem bsWorld
--         --
--         -- lsWorld = LS.world
--         -- lsEnv = fromWorld lsWorld
--         -- lsProb = toProblem lsWorld
--         --
--         simpWorld = SS.world
--         ssEnv = fromWorld simpWorld
--         ssProb = toProblem simpWorld
--
--         -- wsWorld = WS.world
--         -- wsEnv = fromWorld wsWorld
--         -- wsProb = toProblem wsWorld
--
--         initKnl  = initialKnowledge dom (probObjs ssProb) (Env.toState ssEnv)
--         dom = sokobanDomain
--         -- astar = Astar Nothing
