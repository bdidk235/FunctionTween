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
		Pauses the tween
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

local function lerpValue(valueA: any, valueB: any, alpha: number)
	local Type = typeof(valueA)

	if Type == "boolean" or Type == "EnumItem" then
		return valueB
	elseif Type == "number" then
		return lerp(valueA, valueB, alpha)
	elseif builtInLerps[Type] then
		return valueA:Lerp(valueB, alpha)
	elseif Type == "Rect" then
		return Rect.new(valueA.Min:Lerp(valueB.Min, alpha), valueA.Max:Lerp(valueB.Max, alpha))
	elseif Type == "UDim" then
		return UDim.new(lerp(valueA.Scale, valueB.Scale, alpha), lerp(valueA.Offset, valueB.Offset, alpha))
	elseif Type == "Vector2int16" then
		return Vector2int16.new(lerp(valueA.X, valueB.X, alpha), lerp(valueA.Y, valueB.Y, alpha))
	end

	error(`lerpValue: Unsupported type {Type}`)
end

--[[
	Equivalent to `TweenService:Create`:
	- `TweenService:Create(instance, tweenInfo, props)`: `
	local tweenFunc = FunctionTween.InstanceProps(instance, props)
	local tween = FunctionTween.new(tweenFunc, tweenInfo)
	`
	- `Tween:Play()`: `tween.Play(0, 1)`

	@param instance Instance to tween
	@param methodProps { [string]: any (goal) }
	@return function Function to use for tweening
]]
local function InstanceProps(instance: Instance, props: { [string]: any })
	local instanceAny = instance :: any

	local initialValues = {}
	for name, finalValue in props do
		assert(typeof(instanceAny[name]) == typeof(finalValue), "Initial and final values must be of the same type")
		local success, err = pcall(function()
			initialValues[name] = instanceAny[name]
		end)
		if not success then error(`Failed to get property '{name}' for '{instance:GetFullName()}': {err}`) end
	end

	return function(alpha: number)
		for name, value in props do
			local initialValue = initialValues[name]
			local success, err = pcall(function()
				local newValue = lerpValue(initialValue, value, alpha)
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

	@param instance Instance to tween
	@param methodProps { [string]: { any (initialValue), any (finalValue) } }
	@return function Function to use for tweening
]]
local function InstanceMethods(instance: Instance, methodProps: { [string]: { any } })
	local instanceAny = instance :: any

	for _, propData in methodProps do
		local initialValue, finalValue = propData[1], propData[2]
		assert(typeof(initialValue) == typeof(finalValue), "Initial and final values must be of the same type")
	end

	local initialValues = {}
	for name, propData in methodProps do
		initialValues[name] = propData[1]
	end

	return function(alpha: number)
		for name, propData in methodProps do
			local initialValue = initialValues[name]
			local success, err = pcall(function()
				local newValue = lerpValue(initialValue, propData[2], alpha)
				instanceAny[name](instance, newValue)
			end)
			if not success then error(`Failed to set property '{name}' for '{instance:GetFullName()}': {err}`) end
		end
	end
end

return {
	new = new,

	-- Equivalents
	InstanceProps = InstanceProps,
	InstanceMethods = InstanceMethods,
}
