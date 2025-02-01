# PhysicsTween

FunctionTween-like way to do [Physics-Based Tweens](https://devforum.roblox.com/t/howto-physics-based-tweenservice/2873727) with FunctionTween

[Roblox Model](https://create.roblox.com/store/asset/106920082876794/PhysicsTween) | [Wally](https://wally.run/package/bdidk235/physicstween) | [GitHub Release](https://github.com/bdidk235/FunctionTween/releases/latest)

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

Otherwise it's be too different from [FunctionTween](https://github.com/bdidk235/FunctionTween?tab=readme-ov-file#usage).
