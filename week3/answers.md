# Why does the `price0CumulativeLast` and `price1CumulativeLast` never decrement?
As the variable name says, it contains a cumulative price.
This means that the more the time elapsed, the more it grows (theoretically).
        
Even if we suppose a scenario in which the token price goes to 0:
$P$ at $t_n$ $=$ $100$, $P$ at $t_{n-1}$ $= 0$
the price cumulative variable is not going to increase anymore, since the token price is now 0, but it isn’t decrementing aswell.        
$\sum_{i=0}^{n-1} P_n (T_{n+1} - T_n) = \text{price cumulative}$
        
Different scenario would be for the price average, because in that case the price cumulative is divided by the time elapsed.
$\frac{\text{price cumulative}}{T_n}$


# How do you write a contract that uses the oracle?
In order to write a contract that leverages UniswapV2 twap mechanism we should use FixedPoint.uq112x112 with priceCumulative variables and have:
- an update function which updates priceCumulative0Last, priceCumulative1Last and blockTimestampLast (in order to get the time elapsed)
- a function to get the price average of the last period, we can do that by subtracting priceCumulativeLast to priceCumulative (unchecked) and dividing the result by the time elapsed.


# Why are `price0CumulativeLast` and `price1CumulativeLast` stored separately? Why not just calculate ``price1CumulativeLast = 1/price0CumulativeLast`?
You can do price1/price0 or viceversa to calculate the spot price of a token (in terms of the other token). With priceCumulative this wouldn’t work because they are two separate variables not related, since the k constant and prices could have changed by a lot during the history of the pair and the other variable has no way to keep track of that.