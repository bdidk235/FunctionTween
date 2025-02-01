--[[
	FunctionTween - Tween whatever you want, however you want.

	Repository: https://github.com/bdidk235/FunctionTween
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Signal = require(script.Parent.Signal)
type Signal<T...> = Signal.Signal<T...>

function lerp(a: number, b: number, t: number)
	return a * (1 - t) + b * t
end
local function delayCallback(delayTime: number, callback: () -> (), ...: any): thread?
	if delayTime == 0 then
		return callback(...)
	else
		return task.delay(delayTime, callback, ...)
	end
end

export type TweenSignal =
	RBXScriptSignal<number>
	| { Connect: (self: any, callback: (number) -> ()) -> any }
	| { RenderStepName: string, RenderPriority: number }

export type ExtendedTweenInfo = TweenInfo | {
	TweenInfo: TweenInfo,
	-- Overrides TweenInfo's EasingStyle and EasingDirection
	EasingFunction: ((number) -> number)?,
}

export type FunctionTween = {
	Play: (startValue: number, endValue: number, tweenInfo: ExtendedTweenInfo?) -> (),
	Pause: () -> (),
	Resume: () -> (),
	Cancel: () -> (),

	PlaybackState: Enum.PlaybackState,
	Completed: Signal<Enum.PlaybackState>,
}

--[[
	Creates a new FunctionTween table.

	@param func -- Function to use for tweening.
	@param initialTweenInfo -- TweenInfo to use for playing, if not provided in `.play`.
	@param tweenSignal -- What to update the function on
	@return -- New FunctionTween table
]]
local function new(
	func: (value: number, deltaTime: number) -> (),
	initialTweenInfo: ExtendedTweenInfo?,
	tweenSignal: TweenSignal?
)
	local self = {
		PlaybackState = Enum.PlaybackState.Begin,
		Completed = Signal.new(),
	}

	local currentTween = nil :: Tween?
	local cancelFunc = nil :: (() -> ())?
	local delayedThread: thread?

	--[[
		Plays the tween.

		@param startValue -- Start Number
		@param endValue -- End Number
		@param tweenInfo -- TweenInfo to use, overrides provided in `.new`
	]]
	local function play(startValue: number, endValue: number, tweenInfo: ExtendedTweenInfo?)
		self.PlaybackState = Enum.PlaybackState.Begin

		if cancelFunc then
			cancelFunc()
			cancelFunc = nil
		end

		tweenInfo = tweenInfo or initialTweenInfo
		local actualTweenInfo = if typeof(tweenInfo) == "table" and typeof(tweenInfo.TweenInfo) == "TweenInfo"
			then tweenInfo.TweenInfo
			else tweenInfo
		assert(typeof(actualTweenInfo) == "TweenInfo", "TweenInfo is missing, add TweenInfo to '.Play' or '.new'.")

		local easingFunction = function(alpha: number)
			return TweenService:GetValue(alpha, actualTweenInfo.EasingStyle, actualTweenInfo.EasingDirection)
		end
		if typeof(tweenInfo) == "table" and typeof(tweenInfo.EasingFunction) == "function" then
			easingFunction = tweenInfo.EasingFunction
		end

		if tweenSignal then
			self.PlaybackState = actualTweenInfo.DelayTime > 0 and Enum.PlaybackState.Delayed
				or Enum.PlaybackState.Playing

			local cancelDelayedThread = function()
				if delayedThread then
					if coroutine.status(delayedThread) == "suspended" then task.cancel(delayedThread) end
					delayedThread = nil
				end
			end

			cancelFunc = cancelDelayedThread

			-- Thanks to MethodTween for figuring this out
			delayedThread = delayCallback(actualTweenInfo.DelayTime, function()
				self.PlaybackState = Enum.PlaybackState.Playing

				local repeatCount = (actualTweenInfo.RepeatCount + 1) * (if actualTweenInfo.Reverses then 2 else 1)
				local timesRepeated = 0

				local _time = 0
				local lastFrameTime = 0
				local function tweenCallback()
					if self.PlaybackState == Enum.PlaybackState.Cancelled then return end
					if self.PlaybackState == Enum.PlaybackState.Completed then return end

					local currentFrameTime = os.clock()
					local deltaTime = currentFrameTime - lastFrameTime
					lastFrameTime = currentFrameTime

					if self.PlaybackState == Enum.PlaybackState.Paused then return end -- Don't want to bother disconencting

					_time += deltaTime

					local alpha = math.min(_time / actualTweenInfo.Time - timesRepeated, 1)
					local tweenAlpha = easingFunction(alpha)
					if actualTweenInfo.Reverses and timesRepeated % 2 == 1 then tweenAlpha = 1 - tweenAlpha end

					func(lerp(startValue, endValue, tweenAlpha), deltaTime)

					-- TODO: Make repeating more accurate to TweenService
					if alpha >= 1 then
						timesRepeated += 1
					end

					if timesRepeated >= repeatCount and actualTweenInfo.RepeatCount >= 0 then
						self.PlaybackState = Enum.PlaybackState.Completed
						if cancelFunc then
							cancelFunc()
							cancelFunc = nil
						end
					end
				end

				lastFrameTime = os.clock()
				if typeof(tweenSignal) == "table" and (tweenSignal :: any).RenderStepName then
					RunService:BindToRenderStep(
						(tweenSignal :: any).RenderStepName,
						(tweenSignal :: any).RenderPriority,
						tweenCallback
					)
					cancelFunc = function()
						RunService:UnbindFromRenderStep((tweenSignal :: any).RenderStepName)
						cancelDelayedThread()
					end
				else
					local connection = (tweenSignal :: any):Connect(tweenCallback)
					cancelFunc = function()
						connection:Disconnect()
						cancelFunc = nil

						self.Completed:Fire(self.PlaybackState)
						cancelDelayedThread()
					end
				end
			end)
		else
			local temporaryValue = Instance.new("NumberValue")
			temporaryValue.Value = 0

			local lastAlpha = 0
			local valueChanged = temporaryValue:GetPropertyChangedSignal("Value"):Connect(function()
				local alpha = temporaryValue.Value
				local deltaTime = (alpha - lastAlpha) * actualTweenInfo.Time
				lastAlpha = alpha

				local tweenAlpha = easingFunction(alpha)
				func(lerp(startValue, endValue, tweenAlpha), deltaTime)
			end)

			local linearTweenInfo = TweenInfo.new(
				actualTweenInfo.Time,
				-- Doing linear tween for custom Easing Function and deltaTime
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,

				actualTweenInfo.RepeatCount,
				actualTweenInfo.Reverses,
				actualTweenInfo.DelayTime
			)
			local tween = TweenService:Create(temporaryValue, linearTweenInfo, {
				Value = 1,
			})
			currentTween = tween
			tween:Play()

			self.PlaybackState = tween.PlaybackState
			local playbackStateChanged = tween:GetPropertyChangedSignal("PlaybackState"):Connect(function()
				self.PlaybackState = tween.PlaybackState
			end)

			local tweenCompleted
			tweenCompleted = tween.Completed:Connect(function(playbackState)
				currentTween = nil
				cancelFunc = nil

				tweenCompleted:Disconnect()
				playbackStateChanged:Disconnect()
				tween:Destroy()
				valueChanged:Disconnect()
				temporaryValue:Destroy()

				self.Completed:Fire(playbackState)
			end)
			cancelFunc = function()
				tween:Cancel() -- Fires tween.Completed
			end
		end
	end

	--[[
		Pauses the tween.
	]]
	local function pause()
		if self.PlaybackState == Enum.PlaybackState.Begin then return end
		if self.PlaybackState ~= Enum.PlaybackState.Playing then return end

		if currentTween then
			currentTween:Pause()
		else
			self.PlaybackState = Enum.PlaybackState.Paused
		end
	end

	--[[
		Resumes the tween after it was paused.
	]]
	local function resume()
		if self.PlaybackState == Enum.PlaybackState.Begin then return end

		if currentTween then
			currentTween:Play()
		else
			self.PlaybackState = Enum.PlaybackState.Playing
		end
	end

	--[[
		Cancels the tween, it cannot be resumed.
	]]
	local function cancel()
		if self.PlaybackState == Enum.PlaybackState.Begin then return end

		if not currentTween then self.PlaybackState = Enum.PlaybackState.Cancelled end

		if cancelFunc then
			cancelFunc()
			cancelFunc = nil
		end
	end

	self.Play = play
	self.Pause = pause
	self.Resume = resume
	self.Cancel = cancel

	return self :: FunctionTween
end

-- Instance Props and Methods to Function (Also taken from MethodTween)
local builtInLerps = {
	["CFrame"] = true,
	["Vector3"] = true,
	["Vector2"] = true,
	["UDim2"] = true,
	["Color3"] = true,
}

--[[
	Returns a value between `valueA` and `valueB` based on `alpha`, used internally for Equivalents.

	@param valueA T -- Start Value (returns when alpha is 0)
	@param valueB T -- End Value (returns when alpha is 1)
	@param alpha number -- Alpha to return value from valueA and valueB
	@return T -- A value between valueA and valueB based on alpha

	@since v0.1.1
]]
local function LerpValue<T>(valueA: T, valueB: T, alpha: number): T
	-- Entirely Avoiding Luau type checker because I don't want to deal with it.
	local anyA = valueA :: any
	local anyB = valueB :: any

	local valueType = typeof(valueA)

	if valueType == "boolean" or valueType == "EnumItem" then
		return anyB
	elseif valueType == "number" then
		return lerp(anyA, anyB, alpha) :: any
	elseif builtInLerps[valueType] then
		return anyA:Lerp(anyB, alpha) :: any
	elseif valueType == "Rect" then
		return Rect.new(anyA.Min:Lerp(anyB.Min, alpha), anyA.Max:Lerp(anyB.Max, alpha)) :: any
	elseif valueType == "UDim" then
		return UDim.new(lerp(anyA.Scale, anyB.Scale, alpha), lerp(anyA.Offset, anyB.Offset, alpha)) :: any
	elseif valueType == "Vector2int16" then
		return Vector2int16.new(lerp(anyA.X, anyB.X, alpha), lerp(anyA.Y, anyB.Y, alpha)) :: any
	end

	error(`LerpValue: Unsupported type '{valueType}'`)
end

--[[
	Equivalent to `TweenService:Create`:
	- `TweenService:Create(instance, tweenInfo, props)`: `
	local tweenFunc = FunctionTween.InstanceProps(instance, props)
	local tween = FunctionTween.new(tweenFunc, tweenInfo)
	`
	- `Tween:Play()`: `tween.Play(0, 1)`

	@param instance -- Instance to tween
	@param props -- { [string]: any (goal) }
	@return (alpha: number) -> () -- Function with alpha argument
]]
local function InstanceProps(instance: Instance, props: { [string]: any })
	local instanceAny = instance :: any

	local initialValues = {}
	for name, finalValue in props do
		local success, err = pcall(function()
			assert(typeof(instanceAny[name]) == typeof(finalValue), "Initial and final values must be of the same type")
			-- Check if you can tween before adding initial value
			local _ = LerpValue(instanceAny[name], instanceAny[name], 0)
			initialValues[name] = instanceAny[name]
		end)
		if not success then error(`Failed to get property '{name}' for '{instance:GetFullName()}': {err}`) end
	end

	return function(alpha: number)
		for name, value in props do
			local initialValue = initialValues[name]
			local success, err = pcall(function()
				local newValue = LerpValue(initialValue, value, alpha)
				instanceAny[name] = newValue
			end)
			if not success and not initialValue then
				error(`Failed to set property '{name}' for '{instance:GetFullName()}': {err}`)
			end
		end
	end
end

--[[
	Equivalent to `MethodTween.new`:
	- `.new(instance, tweenInfo, methodProps)`: `
	local tweenFunc = FunctionTween.InstanceMethods(instance, methodProps)
	local tween = FunctionTween.new(tweenFunc, tweenInfo)
	`
	- `:Play()`: `tween.Play(0, 1)`

	@param instance -- Instance to tween
	@param methodProps -- { [string]: { any (initialValue), any (finalValue) } }
	@return (alpha: number) -> () -- Function with alpha argument
]]
local function InstanceMethods(instance: Instance, methodProps: { [string]: { any } })
	local instanceAny = instance :: any

	for name, propData in methodProps do
		local initialValue, finalValue = propData[1], propData[2]
		local success, err = pcall(function()
			assert(typeof(initialValue) == typeof(finalValue), "Initial and final values must be of the same type")
			local _ = LerpValue(initialValue, finalValue, 0)
		end)
		if not success then error(`Failed to get property '{name}' for '{instance:GetFullName()}': {err}`) end
	end

	local initialValues = {}
	for name, propData in methodProps do
		initialValues[name] = propData[1]
	end

	return function(alpha: number)
		for name, propData in methodProps do
			local initialValue = initialValues[name]
			local success, err = pcall(function()
				local newValue = LerpValue(initialValue, propData[2], alpha)
				instanceAny[name](instance, newValue)
			end)
			if not success then error(`Failed to set property '{name}' for '{instance:GetFullName()}': {err}`) end
		end
	end
end

return {
	new = new,

	LerpValue = LerpValue,
	-- Equivalents
	InstanceProps = InstanceProps,
	InstanceMethods = InstanceMethods,
}
