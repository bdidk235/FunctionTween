# FunctionTween

Tween whatever you want, however you want.

[Roblox Model](https://create.roblox.com/store/asset/119180526446463/FunctionTween) | [Wally](https://wally.run/package/bdidk235/functiontween) | [Github Release](https://github.com/bdidk235/FunctionTween/releases/latest)

## Usage

A simple example for moving a part, using `PivotTo`.

```luau
local FunctionTween = require(path.to.FunctionTween)

local PartToMove = workspace.PartToMove

local StartingPivot = PartToMove:GetPivot()
local GoalPivot = StartingPivot * CFrame.new(0, 0, 10)

local tween = FunctionTween.new(function(t)
	PartToMove:PivotTo(StartingPivot:Lerp(GoalPivot, t))
end, TweenInfo.new(1))
tween.Play(0, 1)
```

<details> <summary> <b>API Reference</b> </summary>

### FunctionTween.new

Creates a new `FunctionTween` table.

```luau
local RunService = game:GetService("RunService")

local FunctionTween = require(path.to.FunctionTween)

local easingFunction = function(x: number)
	return x ^ 2
end

local tween = FunctionTween.new(
	-- The function to tween
	function(t)
		PartToMove:PivotTo(StartingPivot:Lerp(GoalPivot, t))
	end,
	-- Can be a `TweenInfo` or a table with `TweenInfo` and `EasingFunction`
	{
		TweenInfo = TweenInfo.new(1),
		EasingFunction = easingFunction
	},
	-- What to update the function on (Based on MethodTween)
	RunService.Stepped
)
```

## New FunctionTween

### Functions

#### tween.Play

Plays the tween.

```luau
tween.Play(
	-- Start number
	0,
	-- End number
	1,
	-- Can be extended like `.new`'s TweenInfo
	TweenInfo.new(1)
)
```

#### tween.Pause

Pauses the tween.

```luau
tween.Pause()
```

#### tween.Resume

Resumes the tween after it was paused.

```luau
tween.Resume()
```

#### tween.Cancel

Cancels the tween, it cannot be resumed.

```luau
tween.Cancel()
```

### Properties

#### tween.PlaybackState

The playback state of the tween.

#### tween.Completed

Fires when the tween is completed.

```luau
tween.Play(0, 1)
tween.Completed:Wait()
print("Tween completed!")
```

## Equivalents

#### FunctionTween.InstanceProps

Equivalent to `TweenService:Create`

```luau
local PartToMove = workspace.PartToMove

local tweenFunc = FunctionTween.InstanceProps(
	PartToMove,
	{ CFrame = PartToMove.CFrame * CFrame.new(0, 0, 10) }
)
local tween = FunctionTween.new(tweenFunc)
```

#### FunctionTween.InstanceMethods

Equivalent to `MethodTween.new`

```luau
local PartToMove = workspace.PartToMove

local StartingPivot = PartToMove:GetPivot()
local GoalPivot = StartingPivot * CFrame.new(0, 0, 10)

local tweenFunc = FunctionTween.InstanceMethods(
	workspace.PartToMove,
	{ PivotTo = { StartingPivot, GoalPivot } }
)
local tween = FunctionTween.new(tweenFunc)
```

</details>

## Contributing

You will need [Rokit](https://github.com/rojo-rbx/rokit) (or [Aftman](https://github.com/LPGhatguy/aftman)) to install tools.

You can `rojo serve serve.project.json` to a Baseplate for Tests in Workspace, and Packages in ReplicatedStorage.
