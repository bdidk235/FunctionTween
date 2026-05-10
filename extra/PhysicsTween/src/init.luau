--[[
	PhysicsTween - FunctionTween-like way to do Physics-Based Tweens with FunctionTween
	See: https://devforum.roblox.com/t/howto-physics-based-tweenservice/2873727

	Repository: https://github.com/bdidk235/FunctionTween/tree/main/extra/PhysicsTween
]]
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)
type Signal<T...> = Signal.Signal<T...>

local FunctionTween = require(script.Parent.FunctionTween)
type FunctionTween = FunctionTween.FunctionTween
type ExtendedTweenInfo = FunctionTween.ExtendedTweenInfo
type TweenSignal = FunctionTween.TweenSignal

type PTObject = {
	tween: FunctionTween,

	model: PVInstance,
	tweenSignal: (TweenSignal | "None")?,

	startingCFrame: CFrame,
	goalCFrame: CFrame,
}

export type PhysicsTween = {
	Play: (newGoalCFrame: CFrame, tweenInfo: ExtendedTweenInfo?) -> (),
	Pause: (s: never?) -> (),
	Resume: (s: never?) -> (),
	Cancel: (s: never?) -> (),

	PlaybackState: Enum.PlaybackState,
	Completed: Signal<Enum.PlaybackState>,
}

local function velocitiesUpdater(model: Instance)
	local previousCFrames = {}

	if model:IsA("BasePart") then previousCFrames[model] = model.CFrame end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then previousCFrames[descendant] = model.CFrame end
	end

	local function updatePart(part: BasePart, deltaSpeed: number)
		part.AssemblyLinearVelocity = (part.Position - previousCFrames[part].Position) * deltaSpeed
		part.AssemblyAngularVelocity = Vector3.new(previousCFrames[part]:ToObjectSpace(part.CFrame):ToEulerAngles())
			* deltaSpeed
		previousCFrames[part] = part.CFrame
	end

	return function(deltaSpeed: number)
		if model:IsA("BasePart") then updatePart(model, deltaSpeed) end
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then updatePart(descendant, deltaSpeed) end
		end
	end
end

local function play(object: PTObject, newGoalPivot: CFrame, tweenInfo: ExtendedTweenInfo?)
	local o = object

	o.startingCFrame = o.model:GetPivot()
	o.goalCFrame = newGoalPivot

	o.tween.Play(0, 1, tweenInfo)
end

local function pause(object: PTObject)
	local o = object

	o.tween.Pause()
	o.updateVelocities(0)
end

local function cancel(object: PTObject)
	local o = object

	o.tween.Cancel()
	o.updateVelocities(0)
end

--[[
	Creates a new PhysicsTween table.

	@param model -- Model to use for tweening.
	@param initialTweenInfo -- TweenInfo to use for playing, if not provided in `.play`.
	@param tweenSignal -- What to update the function on
	@return -- New PhysicsTween table
]]
local function new(model: PVInstance, initialTweenInfo: ExtendedTweenInfo?, tweenSignal: (TweenSignal | "None")?)
	local self = {} :: PhysicsTween
	self.Completed = Signal.new()

	local object = {
		model = model,
		tweenSignal = tweenSignal,

		startingCFrame = model:GetPivot(),
		goalCFrame = CFrame.new(),

		updateVelocities = velocitiesUpdater(model),
	} :: PTObject

	local lastFrameTime = nil :: number?
	local lastDeltaTime = nil :: number?

	local tween = FunctionTween.new(function(alpha, deltaTime)
		local currentFrameTime = os.clock()
		lastFrameTime = currentFrameTime
		lastDeltaTime = deltaTime

		local deltaSpeed = 1 / deltaTime

		local newCFrame = object.startingCFrame:Lerp(object.goalCFrame, alpha)
		model:PivotTo(newCFrame)

		object.updateVelocities(deltaSpeed)
	end, initialTweenInfo, if tweenSignal ~= "None" then (tweenSignal or RunService.PreSimulation) else nil)

	object.tween = tween
	self.Resume = tween.Resume
	self.PlaybackState = tween.PlaybackState

	--[[
		Plays the tween.

		@param newGoalPivot -- What Pivot the model goes to
		@param tweenInfo -- TweenInfo to use, overrides provided in `.new`
	]]
	self.Play = function(newGoalPivot: CFrame, tweenInfo: ExtendedTweenInfo?)
		assert(
			typeof(newGoalPivot) == "CFrame",
			"[PhysicsTween]: newGoalPivot is not a CFrame for PT.Play, either not provided or called using ':' instead of '.'"
		)
		local completed
		completed = tween.Completed:Connect(function(playbackState)
			local currentFrameTime = lastFrameTime
			task.delay(lastDeltaTime or 0, function()
				if lastFrameTime ~= currentFrameTime then return end
				object.updateVelocities(0)
			end)

			completed:Disconnect()
			self.Complted:Fire(playbackState)
		end)
		play(object, newGoalPivot, tweenInfo)
	end

	--[[
		Pauses the tween.
	]]
	self.Pause = function(s: never?)
		if s ~= nil then warn("[PhysicsTween]: Expected '.' not ':', PT.Pause will still work as expected.") end
		pause(object)
	end

	--[[
		Resumes the tween after it was paused.
	]]
	self.Resume = function(s: never?)
		if s ~= nil then warn("[PhysicsTween]: Expected '.' not ':', PT.Resume will still work as expected.") end
		tween.Resume()
	end

	--[[
		Cancels the tween, it cannot be resumed.
	]]
	self.Cancel = function(s: never?)
		if s ~= nil then warn("[PhysicsTween]: Expected '.' not ':', PT.Cancel will still work as expected.") end
		cancel(object)
	end

	return self
end

return {
	new = new,
}
