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

local function changeVelocties(object: Instance, velocity: Vector3, angularVelocity: Vector3)
	if object:IsA("BasePart") then
		object.AssemblyLinearVelocity = velocity
		object.AssemblyAngularVelocity = angularVelocity
	end
	for _, part in pairs(object:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = velocity
			part.AssemblyAngularVelocity = angularVelocity
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
	changeVelocties(o.model, Vector3.zero, Vector3.zero)
end

local function cancel(object: PTObject)
	local o = object

	o.tween.Cancel()
	changeVelocties(o.model, Vector3.zero, Vector3.zero)
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

	local object = {
		model = model,
		tweenSignal = tweenSignal,

		startingCFrame = model:GetPivot(),
		goalCFrame = CFrame.new(),
	} :: PTObject

	local lastFrameTime = nil :: number?

	local tween = FunctionTween.new(function(alpha, deltaTime)
		local currentFrameTime = os.clock()
		lastFrameTime = currentFrameTime

		local deltaSpeed = 1 / deltaTime

		local newCFrame = object.startingCFrame:Lerp(object.goalCFrame, alpha)

		local velocity = (newCFrame.Position - model:GetPivot().Position) * deltaSpeed
		local angularVelocity = Vector3.new((model:GetPivot():ToObjectSpace(newCFrame)):ToEulerAngles()) * deltaSpeed
		changeVelocties(model, velocity, angularVelocity)

		if alpha == 1 then
			task.delay(deltaTime, function()
				if lastFrameTime ~= currentFrameTime then return end
				changeVelocties(model, Vector3.zero, Vector3.zero)
			end)
		end

		model:PivotTo(newCFrame)
	end, initialTweenInfo, if tweenSignal ~= "None" then (tweenSignal or RunService.PreSimulation) else nil)

	object.tween = tween
	self.Resume = tween.Resume
	self.PlaybackState = tween.PlaybackState
	self.Completed = tween.Completed

	--[[
		Plays the tween.

		@param newGoalPivot -- What Pivot the model goes to
		@param tweenInfo -- TweenInfo to use, overrides provided in `.new`
	]]
	self.Play = function(newGoalPivot: CFrame, tweenInfo: ExtendedTweenInfo?)
		assert(
			typeof(newGoalPivot) == "CFrame",
			"newGoalPivot is not a CFrame for PT.Play, either not provided or called using ':' instead of '.'"
		)
		play(object, newGoalPivot, tweenInfo)
	end

	--[[
		Pauses the tween.
	]]
	self.Pause = function(s: never?)
		if s ~= nil then warn("Expected '.' not ':', PT.Pause will still work as expected.") end
		pause(object)
	end

	--[[
		Resumes the tween after it was paused.
	]]
	self.Resume = function(s: never?)
		if s ~= nil then warn("Expected '.' not ':', PT.Resume will still work as expected.") end
		tween.Resume()
	end

	--[[
		Cancels the tween, it cannot be resumed.
	]]
	self.Cancel = function(s: never?)
		if s ~= nil then warn("Expected '.' not ':', PT.Cancel will still work as expected.") end
		cancel(object)
	end

	return self
end

return {
	new = new,
}
