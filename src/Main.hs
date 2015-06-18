module Main where

import           Environment                              as Env
import           Environment.Sokoban
import           Environment.Sokoban.PDDL
import qualified Environment.Sokoban.Samples.BigSample    as BS
import qualified Environment.Sokoban.Samples.LargeSample  as LS
import qualified Environment.Sokoban.Samples.SimpleSample as SS
import qualified Environment.Sokoban.Samples.WikiSample   as WS
import           Environment.Sokoban.SokobanDomain
import           Environment.Sokoban.SokobanView
import           Learning
import qualified Learning.PDDL                            as PDDL
import qualified Learning.PDDL.ConditionalKnowledge       as CK
import           Learning.PDDL.Experiment
import           Learning.PDDL.NonConditionalKnowledge
import qualified Learning.PDDL.NonConditionalTypes        as NCT
import           Learning.PDDL.OptimisticStrategy
import           Planning
import           Planning.PDDL

import           Control.Arrow                            (second, (&&&))
import           Control.Monad                            (unless)
import           Data.List                                (intercalate, tails)
import qualified Data.Map                                 as Map
import           Data.Set                                 ((\\))
import           Data.Set                                 (Set)
import qualified Data.Set                                 as Set
import           Graph.Search.Astar                       as Astar
import           Logic.Formula
import           System.Console.ANSI
import           System.Directory                         (removeFile)
import           System.IO.Error
import           Text.Show.Pretty

data Astar = Astar (Maybe Int) deriving Show

instance BoundedPlanner Astar where
  setBound (Astar _) = Astar

instance ExternalPlanner Astar PDDLDomain PDDLProblem ActionSpec where
  makePlan (Astar bound) d p =
    case bound of
      Just b -> return $ Astar.searchBounded (PDDLGraph (d,p)) (initialState p) b
      Nothing -> return $ Astar.search (PDDLGraph (d,p)) (initialState p)

type SokoSimStep = SimStep (OptimisticStrategy Astar SokobanPDDL)
                           SokobanPDDL
                           PDDLProblem
                           (NCT.PDDLKnowledge SokobanPDDL)
                           (PDDLExperiment SokobanPDDL)
                           (PDDL.PDDLInfo SokobanPDDL)

lastAction :: SokoSimStep -> Action
lastAction step =
    case PDDL.transitions (ssInfo step) of
        ((_, act, _) : _) -> act
        [] -> error "lastAction: Empty transition list in PDDLInfo."

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

showLearned :: SokoSimStep -> String
showLearned step =  "Step " ++ show (ssStep step) ++ "\n"
                 ++ concatMap showMapping alist where
    alist = Map.toList $ domainKnowledge $ ssKnl step
    showMapping (n, (pk, ek)) = n ++ ": "
                              ++ showEk ek ++ ", "
                              ++ showPk pk ++ "\n"
    showPk (NCT.PreKnowledge knl cands) =  intercalate ", "
                                        $  showKnl knl
                                        ++ [show $ Set.size cands]
    showEk (NCT.EffKnowledge knl) = intercalate ", " $ showKnl knl
    showKnl knl = map (show . Set.size) [ NCT.posKnown knl
                                        , NCT.posUnknown knl
                                        , NCT.negKnown knl
                                        , NCT.negUnknown knl
                                        ]

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
               -- >> showLearned steps
               >> showBound steps

historyFile :: FilePath
historyFile = "statistics"

writeHistory :: PDDLDomain -> [SokoSimStep] -> IO ()
writeHistory dom hist = writeFile historyFile cont where
    cont =  (concatMap showActSize actSizes)
         ++ concatMap showLearned (reverse hist)
    actSizes = map (id &&& allPredsForAction dom)
                   (map asName $ dmActionsSpecs dom)
    showActSize (n, s) = n ++ ": " ++ show (Set.size s) ++ "\n"

main :: IO ()
main = do
    catchIOError (removeFile logPath) (\_ -> return ())
    clearScreen
    setTitle "SOKOBAN!"

    hist <- runAll writeSim optStrat initKnl [ (ssEnv, ssProb)
                                             , (lsEnv, lsProb)
                                            --  , (bsEnv, bsProb)
                                             ]
    writeHistory dom hist
    -- putStrLn (ppShow fenv)
    -- putStrLn (ppShow dom''')
    -- writeFile "sokoDom.pddl" $ writeDomain dom
    -- writeFile "sokoProb.pddl" $ writeProblem wsProb
    return ()
    where
        logPath = "./log.log"

        optStrat = OptimisticStrategy (Astar Nothing, Nothing)
        -- bsWorld = BS.world
        -- bsEnv = fromWorld bsWorld
        -- bsProb = toProblem bsWorld
        --
        lsWorld = LS.world
        lsEnv = fromWorld lsWorld
        lsProb = toProblem lsWorld

        simpWorld = SS.world
        ssEnv = fromWorld simpWorld
        ssProb = toProblem simpWorld

        -- wsWorld = WS.world
        -- wsEnv = fromWorld wsWorld
        -- wsProb = toProblem wsWorld

        initKnl  = initialKnowledge dom (probObjs ssProb) (Env.toState ssEnv)
        dom = sokobanDomain
        -- astar = Astar Nothing
