--[[
	PhysicsTween - FunctionTween-like way to do Physics-Based Tweens with FunctionTween
	See: https://devforum.roblox.com/t/howto-physics-based-tweenservice/2873727

	Repository: https://github.com/bdidk235/FunctionTween/tree/main/extra/PhysicsTween
]]
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)
type Signal<T...> = Signal.Signal<T...>

local FunctionTween = require(script.Parent.FunctionTween)
type ExtendedTweenInfo = FunctionTween.ExtendedTweenInfo
type TweenSignal = FunctionTween.TweenSignal

export type PhysicsTween = {
	Play: (newGoalCFrame: CFrame, tweenInfo: ExtendedTweenInfo?) -> (),
	Pause: () -> (),
	Resume: () -> (),
	Cancel: () -> (),

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

--[[
	Creates a new PhysicsTween table.

	@param model -- Model to use for tweening.
	@param initialTweenInfo -- TweenInfo to use for playing, if not provided in `.play`.
	@param tweenSignal -- What to update the function on
	@return -- New PhysicsTween table
]]
local function new(model: PVInstance, initialTweenInfo: ExtendedTweenInfo?, tweenSignal: (TweenSignal | "None")?)
	local startingCFrame = model:GetPivot()
	local goalCFrame = CFrame.new()

	local lastFrameTime = os.clock()
	local tween = FunctionTween.new(function(alpha, deltaTime)
		local currentFrameTime = os.clock()
		lastFrameTime = currentFrameTime

		local deltaSpeed = 1 / deltaTime

		local newCFrame = startingCFrame:Lerp(goalCFrame, alpha)

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

	--[[
		Plays the tween.

		@param newGoalPivot -- What Pivot the model goes to
		@param tweenInfo -- TweenInfo to use, overrides provided in `.new`
	]]
	local function play(newGoalPivot: CFrame, tweenInfo: ExtendedTweenInfo?)
		startingCFrame = model:GetPivot()
		goalCFrame = newGoalPivot

		lastFrameTime = os.clock()
		tween.Play(0, 1, tweenInfo)
	end

	--[[
		Pauses the tween.
	]]
	local function pause()
		tween.Pause()
		changeVelocties(model, Vector3.zero, Vector3.zero)
	end

	--[[
		Cancels the tween, it cannot be resumed.
	]]
	local function cancel()
		tween.Cancel()
		changeVelocties(model, Vector3.zero, Vector3.zero)
	end

	return {
		Play = play,
		Pause = pause,
		Resume = tween.Resume,
		Cancel = cancel,

		PlaybackState = tween.PlaybackState,
		Completed = tween.Completed,
	} :: PhysicsTween
end

return {
	new = new,
}
