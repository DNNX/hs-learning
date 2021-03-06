module Learning.PDDL.NonConditionalKnowledge where

import qualified Learning.PDDL.EffectKnowledge       as Eff
import qualified Learning.PDDL.PreconditionKnowledge as Pre

import           Learning.PDDL.NonConditionalTypes
-- import Data.TupleSet (TupleSet)
-- import qualified Data.TupleSet as TSet
-- import Logic.Formula
import           Data.UnsafeMap
import           Environment
import qualified Learning                            as Lrn
import           Learning.Induction
import qualified Learning.PDDL                       as PDDL
import           Planning
import           Planning.PDDL

-- import           Data.Map                            (Map)
import qualified Data.Map                            as Map
import           Data.Set                            (Set)
import qualified Data.Set                            as Set

instance Environment env => Lrn.Knowledge (PDDLKnowledge env) (PDDL.PDDLInfo env) PDDLProblem where
    analyze knl info = foldl updateKnowledge knl (PDDL.transitions info)
    canAnswer (PDDLKnowledge (_, _, s, _)) prob = isSolved prob s

domainKnowledge :: PDDLKnowledge env -> DomainKnowledge
domainKnowledge (PDDLKnowledge (_, dk, _, _)) = dk

pddlDomain :: PDDLKnowledge env -> PDDLDomain
pddlDomain (PDDLKnowledge (dom, _, _, _)) = dom

knlFromDomKnl :: DomainKnowledge
              -> Name
              -> (PreKnowledge, EffKnowledge)
knlFromDomKnl dmknl actname =
  unsLookup
    ("no action " ++ actname ++ " in " ++ show dmknl)
    actname
    dmknl


updateKnowledge :: PDDLKnowledge env -> Transition -> PDDLKnowledge env
updateKnowledge (PDDLKnowledge (dom, dk, _, allobjs)) trans@(_, (aname, _), s') =
  PDDLKnowledge (dom, dk', s', allobjs)
  where dk' = Map.adjust (f (uppPre, uppEff)) aname dk
        f (f1, f2) (o1, o2) = (f1 o1, f2 o2)
        uppEff = flip (Eff.updateEffectKnl dom allobjs) trans
        uppPre = flip (Pre.update dom allobjs) trans

allPreds :: [Name]
         -> [PredicateSpec]
         -> [Name]
         -> Set FluentPredicate
allPreds consts pSpecs paras = fPreds where
    allParas = map TVar paras ++ map TName consts
    fPreds = Set.unions $ map (allFluents allParas) pSpecs

allPredsForAction :: PDDLDomain -> Name -> Set FluentPredicate
allPredsForAction dom n =
    let aSpec = unsActionSpec dom n
    in allPreds (dmConstants dom) (dmPredicates dom) (asParas aSpec)

actionKnowledgeEff :: [Name]
                -> [PredicateSpec]
                -> [Name]
                -> EffKnowledge
actionKnowledgeEff consts allPs paras =
    let unkns = allPreds consts allPs paras
        knl = Knowledge (Set.empty, Set.empty) (unkns, unkns)
    in EffKnowledge knl

actionKnowledge :: [Name]
                -> [PredicateSpec]
                -> [Name]
                -> (PreKnowledge, EffKnowledge)
actionKnowledge consts allPs paras =
    let unkns = allPreds consts allPs paras
        knl = Knowledge (Set.empty, Set.empty) (unkns, unkns)
    in (PreKnowledge knl Set.empty, EffKnowledge knl)

initialKnowledge :: PDDLDomain -> AllPossibleObjects -> State -> PDDLKnowledge env
initialKnowledge dom allobjs s = PDDLKnowledge (dom, kn, s, allobjs) where
    mapper aSpec = ( asName aSpec
                   , actionKnowledge (dmConstants dom)
                                     (dmPredicates dom)
                                     (asParas aSpec)
                   )
    kn = Map.fromList $ fmap mapper (dmActionsSpecs dom)
