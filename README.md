# FunctionTween

Tween whatever you want, however you want.

## Usage

A simple example for moving a part, using `PivotTo`.

```lua
local FunctionTween = require(path.to.FunctionTween)

local PartToMove = workspace.PartToMove

local StartingPivot = PartToMove:GetPivot()
local GoalPivot = StartingPivot * CFrame.new(0, 0, 10)

local tween = FunctionTween.new(function(t)
	PartToMove:PivotTo(StartingPivot:Lerp(GoalPivot, t))
end, TweenInfo.new(1))
tween.Play(0, 1)
```

## API

### FunctionTween.new

Creates a new `FunctionTween` table.

```lua
local RunService = game:GetService("RunService")

local FunctionTween = require(path.to.FunctionTween)

local easingFunction = function(x: number)
	return (x ^ 2) / 2
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
	-- What to update the function on
	RunService.Stepped
)
```

## New FunctionTween

### Functions

#### tween.Play

Plays the tween.

```lua
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

```lua
tween.Pause()
```

#### tween.Resume

Resumes the tween after it was paused.

```lua
tween.Resume()
```

#### tween.Cancel

Cancels the tween, it cannot be resumed.

```lua
tween.Cancel()
```

### Properties

#### tween.PlaybackState

The playback state of the tween.

#### tween.Completed

Fires when the tween is completed.

```lua
tween.Play(0, 1)
tween.Completed:Wait()
print("Tween completed!")
```

### Equivalents

#### FunctionTween.InstanceProps

Equivalent to `TweenService:Create`

```lua
local PartToMove = workspace.PartToMove

local tween = FunctionTween.new(
	InstanceProps(
		PartToMove,
		{ CFrame = PartToMove.CFrame * CFrame.new(0, 0, 10) }
	)
)
```

#### FunctionTween.InstanceMethods

Equivalent to `MethodTween.new`

```lua
local PartToMove = workspace.PartToMove

local StartingPivot = PartToMove:GetPivot()
local GoalPivot = StartingPivot * CFrame.new(0, 0, 10)

local tween = FunctionTween.new(
	InstanceMethods(
		workspace.PartToMove,
		{ PivotTo = { StartingPivot, GoalPivot } }
	)
)
```
