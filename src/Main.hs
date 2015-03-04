
module Main where

import           System.Console.ANSI
import           System.Directory                         (removeFile)

import           Data.Map                                 ((!))
import Planning.Viewing
import           Data.Maybe
import           Environment                              as Env
import           Environment.Sokoban.SokobanView
import           Environment.Sokoban.PDDL
import qualified Environment.Sokoban.Samples.SimpleSample as SS
import qualified Environment.Sokoban.Samples.LargeSample  as LS
import qualified Environment.Sokoban.Samples.BigSample    as BS
import qualified Environment.Sokoban.Samples.WikiSample   as WS
import           Environment.Sokoban.SokobanDomain
import           Graph.Search.Astar                       as Astar
import           Learning
import           Learning.OptEffectLearn
import           Learning.OptPrecondLearn
import           Planning
import           Planning.PDDL
import           Planning.PDDL.Logic
import           Planning.Planner.FastDownward
import           System.IO.Error
import           Text.Show.Pretty
import           Learning.ManyHypothesis

logPath = "./log.log"

data Astar = Astar (Maybe Int)

instance BoundedPlanner Astar where
  setBound (Astar _) = Astar

instance ExternalPlanner Astar (LearningDomain' PDDLDomain ManyHypothesis PDDLProblem ActionSpec) PDDLProblem ActionSpec where
    makePlan (Astar bound) (LearningDomain' (d,_)) p =
      case bound of
        Just b -> return $ Astar.searchBounded (PDDLGraph (d,p)) (initialState p) b
        Nothing -> return $ Astar.search (PDDLGraph (d,p)) (initialState p)

instance ExternalPlanner FastDownward (LearningDomain' PDDLDomain ManyHypothesis PDDLProblem ActionSpec) PDDLProblem ActionSpec where
    makePlan fd (LearningDomain' (d, _)) = makePlan' fd d

toFormula :: PDDLDomain -> PreDomainHypothesis -> [(String, Formula Argument)]
toFormula dom dHyp =
  map (\as -> (asName as, constructPrecondFormula (dHyp ! asName as)))
                                    $ dmActionsSpecs dom

main :: IO ()
main = do
    catchIOError (removeFile logPath) (\_ -> return ())
    clearScreen
    setTitle "SOKOBAN!"
    --putStrLn (ppShow $ initialState prob)
    (_, dom') <- runv  initDom ssProb ssEnv
    (_, dom'') <- runv  dom' lsProb lsEnv
    (fenv, dom''') <- runv  dom'' bsProb bsEnv
    putStrLn (ppShow fenv)
    putStrLn (ppShow dom''')
    return ()
    where
        bsWorld = BS.world
        bsEnv = fromWorld bsWorld
        bsProb = toProblem bsWorld

        lsWorld = LS.world
        lsEnv = fromWorld lsWorld
        lsProb = toProblem lsWorld

        ssWorld = SS.world
        ssEnv = fromWorld ssWorld
        ssProb = toProblem ssWorld
        --runn = run astar dom prob
        runv ldom = runUntilSolved astar (sokobanView "log.log") ldom
        dom = sokobanDomain
        astar = Astar Nothing
        --fd = mkFastDownard dom prob
        iniPreDomHyp = fromDomain dom :: OptPreHypothesis
        iniEffDomHyp = fromDomain dom :: OptEffHypothesis

        manyhyp = ManyHypothesis [
                         HypBox iniPreDomHyp,
                         HypBox iniEffDomHyp
                      ] :: ManyHypothesis
        initDom = toLearningDomain manyhyp dom
