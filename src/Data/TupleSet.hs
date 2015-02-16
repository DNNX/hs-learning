module Data.TupleSet where

import           Data.Set           (Set, (\\))
import qualified Data.Set           as Set



-- | Gets two unions of a tuples with sets
union :: Ord a => (Set a, Set a) -> (Set a, Set a) -> (Set a, Set a)
union (pos,neg) (pos2,neg2) = (Set.union pos pos2, Set.union neg neg2)

-- | Gets two intersection of a tuples with sets
isSubSetOf :: Ord a => (Set a, Set a) -> (Set a, Set a) -> Bool
isSubSetOf (s1a,s1b) (s2a,s2b) = Set.isSubsetOf s1a s2a && Set.isSubsetOf s1b s2b

intersection :: Ord a => (Set a, Set a) -> (Set a, Set a) -> (Set a, Set a)
intersection (s1a,s1b) (s2a,s2b) = (Set.intersection s1a s2a, Set.intersection s1b s2b)

size :: Ord a =>  (Set a, Set a) -> Int
size (s1,s2) = Set.size s1 + Set.size s2

difference :: Ord a => (Set a, Set a) -> (Set a, Set a) -> (Set a, Set a)
difference (s1a,s1b) (s2a,s2b) = (s1a `Set.difference` s2a, s1b `Set.difference` s2b )

empty :: Ord a => (Set a, Set a)
empty = (Set.empty, Set.empty)