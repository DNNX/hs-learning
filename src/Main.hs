module Main where

import           System.Console.ANSI
import           System.Directory                         (removeFile)

import           ActionViewer
import           Environment as Env
import           Environment.Sokoban.ConsoleView          (visualize)
import           Environment.Sokoban.PDDL
import qualified Environment.Sokoban.Samples.SimpleSample as SS
import qualified Environment.Sokoban.Samples.WikiSample   as WS
import           Environment.Sokoban.SokobanDomain
import           Learning
import           Learning.OptEffectLearn
import           Learning.OptPrecondLearn
import           Planning.Planner.FastDownward
import           Graph.Search.Astar as Astar
import           System.IO.Error
import Planning
import Planning.PDDL
import Planning.PDDL.Samples.SimpleBox
import           Text.Show.Pretty
import Data.Map ((!))
import Data.Maybe
import Planning.PDDL.Logic
logPath = "./log.log"

data Astar = Astar

instance ExternalPlanner Astar PDDLDomain PDDLProblem ActionSpec where
    makePlan _ d p = return $ Astar.search (PDDLGraph (d,p)) (initialState p)

toFormula :: PDDLDomain -> PreDomainHypothesis -> [(String, Formula Argument)]
toFormula dom dHyp =
  map (\as -> (asName as, constructPrecondFormula (dHyp ! asName as)))
                                    $ dmActionsSpecs dom


main :: IO ()
main = do
    catchIOError (removeFile logPath) (\_ -> return ())
    clearScreen
    setTitle "SOKOBAN!"
    putStrLn (ppShow $ initialState prob)
    putStrLn (ppShow (toFormula dom iniPreDomHyp))
    --outp <- runn env iniPreDomHyp iniEffDomHyp Nothing
    -- case outp of
    --   Left (env',preHyp,_,_) ->
    --     let as = fromJust $ actionSpecification dom "move-v"
    --         as' = constructPrecondSchema (preHyp ! "move-v") as
    --       in putStr (ppShow (groundPreconditions as' ["b0x1", "b0x0"]))
    fenv <- runv env iniPreDomHyp iniEffDomHyp Nothing
    putStr (ppShow fenv)
    return ()
    --outp2 <- continue outp
    --printOut outp
    --printOut outp2
    where
        vis _ = return () :: IO ()
        sokoWorld = SS.world
        sokoEnv = fromWorld sokoWorld
        --runn = run astar dom prob
        runv = runnerVisualized astar vis vis dom prob
        -- continue outp =
        --   case outp of
        --     Left (env',preHyp,effHyp,plan) -> runn env' preHyp effHyp plan
        --     Right eror -> error ("stopped " ++ show eror)
        -- printOut outp =
        --   case outp of
        --    Left (env,preHyp,effHyp,_) ->
        --     do putStrLn ("preconds: " ++ (ppShow effHyp))
        --    Right True -> putStrLn ("Success")
        --    Right False -> putStrLn ("failed")
        env = sokoEnv
        dom = sokobanDomain
        prob = toProblem sokoWorld
        --env = SBEnvironment (initialState prob, dom)
        astar = Astar
        -- fd = mkFastDownard dom prob
        iniPreDomHyp = initialPreDomainHyp dom
        iniEffDomHyp = initialHypothesis dom
