# PhysicsTween

FunctionTween-like way to do [Physics-Based Tweens](https://devforum.roblox.com/t/howto-physics-based-tweenservice/2873727) with FunctionTween

# Usage

```lua
local PhysicsTween = require(path.to.PhysicsTween)

-- Model to move and have physics
local ModelToMove = workspace.ModelToMove

local StartingPivot = PartToMove:GetPivot()
local GoalPivot = StartingPivot * CFrame.new(0, 0, -10)

local tween = PhysicsTween.new(PartToMove, TweenInfo.new(1))
tween.Play(GoalPivot)
```
