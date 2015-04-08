module Learning.PDDL.OptimisticStrategy  where

import qualified Learning.PDDL.EffectKnowledge       as Eff
import qualified Learning.PDDL.PreconditionKnowledge as Pre
import           Learning2
import           Learning.Induction
import qualified Learning.PDDL as Lrn
import           Learning.PDDL.NonConditionalKnowledge
import           Learning.PDDL.Experiment
import           Logic.Formula
import           Planning
import           Planning.PDDL
import           Planning.PDDL.Logic
import           Environment

import           Data.Function           (on)
import           Data.List               (deleteBy)
import           Data.Map                (Map)
import qualified Data.Map                as Map
import           Data.Set                (Set, (\\))
import qualified Data.Set                as Set
import           Data.Typeable


newtype (Environment env) =>
        OptimisticStrategy env = OptimisticStrategy ()

instance Environment env => Strategy
            (OptimisticStrategy env)
            env
            PDDLKnowledge
            (PDDLExperiment env)
            Lrn.PDDLInfo
    where
      design strat knl = undefined

effectSchema :: Eff.EffectKnowledge
                      -> ActionSpec
                      -> ActionSpec
effectSchema (Lrn.EffKnowledge kn) aSpec = aSpec { asEffect = eff } where
    addL = Set.map Pred $ (Lrn.posUnknown kn) `Set.union` (Lrn.posKnown kn)
    delL = Set.map (Neg . Pred) (Lrn.negKnown kn)
    eff = Con $ Set.toList $ addL `Set.union` delL

precondFormula :: Pre.PreKnowledge -> Formula Argument
precondFormula (Lrn.PreKnowledge hyp cnf) =
    Con predList
    where negPredList (poss,negs) =  Set.toList (Set.map Pred negs)
                                  ++ Set.toList (Set.map (Neg . Pred) poss)
          orList = Neg . Con . negPredList
          predList =  Set.toList (Set.map Pred (Lrn.posKnown hyp))
                   ++ Set.toList (Set.map (Neg . Pred) (Lrn.negKnown hyp))
                   ++ Set.toList (Set.map orList cnf)

precondSchema :: Pre.PreKnowledge -> ActionSpec -> ActionSpec
precondSchema preKnow aSpec = aSpec { asPrecond = precondFormula preKnow }

schema :: Pre.PreKnowledge -> Eff.EffectKnowledge -> ActionSpec -> ActionSpec
schema pk ek = (effectSchema ek . precondSchema pk)

mkSchema :: DomainKnowledge -> ActionSpec -> ActionSpec
mkSchema kn as = case Map.lookup (asName as) kn of
    Just (pk, ek) -> (effectSchema ek . precondSchema pk) as
    Nothing -> error $  "Optimistic schema construction: lookup of action schema"
                     ++ (asName as) ++ " failed."

makeOptimisticDomain :: PDDLKnowledge -> PDDLDomain
makeOptimisticDomain (PDDLKnowledge (dom, kn, _)) = dom { dmActionsSpecs = as }
    where as = map (mkSchema kn) (dmActionsSpecs dom)
