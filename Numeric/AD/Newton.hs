{-# LANGUAGE Rank2Types, BangPatterns #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.AD.Newton
-- Copyright   :  (c) Edward Kmett 2010
-- License     :  BSD3
-- Maintainer  :  ekmett@gmail.com
-- Stability   :  experimental
-- Portability :  GHC only 
--
-----------------------------------------------------------------------------

module Numeric.AD.Newton
    ( 
    -- * Newton's Method (Forward AD)
      findZero
    , inverse
    , fixedPoint
    , extremum
    -- * Gradient Descent (Reverse AD)
    , gradientDescent
    -- * Exposed Types
    , AD(..)
    , Mode(..)
    ) where

import Prelude hiding (all)
import Numeric.AD.Classes
import Numeric.AD.Internal
import Data.Foldable (all)
import Data.Traversable (Traversable)
import Numeric.AD.Forward (diff, diff2) 
import Numeric.AD.Reverse (grad2) 

-- | The 'findZero' function finds a zero of a scalar function using
-- Newton's method; its output is a stream of increasingly accurate
-- results.  (Modulo the usual caveats.)
--
-- Examples:
--
--  > take 10 $ findZero (\\x->x^2-4) 1  -- converge to 2.0
--
--  > module Data.Complex
--  > take 10 $ findZero ((+1).(^2)) (1 :+ 1)  -- converge to (0 :+ 1)@
--
findZero :: Fractional a => (forall s. Mode s => AD s a -> AD s a) -> a -> [a]
findZero f x0 = iterate (\x -> let (y,y') = diff2 f x in x - y/y') x0
{-# INLINE findZero #-}

-- | The 'inverseNewton' function inverts a scalar function using
-- Newton's method; its output is a stream of increasingly accurate
-- results.  (Modulo the usual caveats.)
--
-- Example:
-- 
-- > take 10 $ inverseNewton sqrt 1 (sqrt 10)  -- converge to 10
--
inverse :: Fractional a => (forall s. Mode s => AD s a -> AD s a) -> a -> a -> [a]
inverse f x0 y = findZero (\x -> f x - lift y) x0
{-# INLINE inverse  #-}

-- | The 'fixedPoint' function find a fixedpoint of a scalar
-- function using Newton's method; its output is a stream of
-- increasingly accurate results.  (Modulo the usual caveats.)
fixedPoint :: Fractional a => (forall s. Mode s => AD s a -> AD s a) -> a -> [a]
fixedPoint f = findZero (\x -> f x - x)
{-# INLINE fixedPoint #-}

-- | The 'extremum' function finds an extremum of a scalar
-- function using Newton's method; produces a stream of increasingly
-- accurate results.  (Modulo the usual caveats.)
extremum :: Fractional a => (forall t s. (Mode t, Mode s) => AD t (AD s a) -> AD t (AD s a)) -> a -> [a]
extremum f x0 = findZero (diff f) x0
{-# INLINE extremum #-}

-- | The 'gradientDescent' function performs a multivariate
-- optimization, based on the naive-gradient-descent in the file
-- @stalingrad\/examples\/flow-tests\/pre-saddle-1a.vlad@ from the
-- VLAD compiler Stalingrad sources.  Its output is a stream of
-- increasingly accurate results.  (Modulo the usual caveats.)  
-- 
-- It uses reverse mode automatic differentiation to compute the gradient.
gradientDescent :: (Traversable f, Fractional a, Ord a) => (forall s. Mode s => f (AD s a) -> AD s a) -> f a -> [f a]
gradientDescent f x0 = go x0 fx0 gx0 0.1 (0 :: Int)
    where
        (fx0, gx0) = grad2 f x0
        go x fx gx !eta !i 
            | eta == 0     = [] -- step size is 0
            | fx1 > fx     = go x fx gx (eta/2) 0 -- we stepped too far
            | all (==0) gx = [] -- gradient is 0
            | otherwise    = x1 : if i == 10
                                  then go x1 fx1 gx1 (eta*2) 0
                                  else go x1 fx1 gx1 eta (i+1)
            where
                -- should check gx = 0 here
                x1 = zipWithT (\xi gxi -> xi - eta * gxi) x gx
                (fx1, gx1) = grad2 f x1
{-# INLINE gradientDescent #-}