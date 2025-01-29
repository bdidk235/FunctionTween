--[[
	FunctionTween-like way to do Physics-Based Tweens with FunctionTween
	See: https://devforum.roblox.com/t/howto-physics-based-tweenservice/2873727
]]
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)
type Signal<T...> = Signal.Signal<T...>

local FunctionTween = require(script.Parent.FunctionTween)
type ExtendedTweenInfo = FunctionTween.ExtendedTweenInfo

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

local function new(model: PVInstance, initialTweenInfo: ExtendedTweenInfo?)
	local startingCFrame = model:GetPivot()
	local goalCFrame = CFrame.new()

	local lastTweenTime = os.clock()
	local tween = FunctionTween.new(function(alpha, deltaTime)
		local currentTweenTime = os.clock()
		lastTweenTime = currentTweenTime

		local deltaSpeed = 1 / deltaTime

		local newCFrame = startingCFrame:Lerp(goalCFrame, alpha)

		local velocity = (newCFrame.Position - model:GetPivot().Position) * deltaSpeed
		local angularVelocity = Vector3.new((model:GetPivot():ToObjectSpace(newCFrame)):ToEulerAngles()) * deltaSpeed
		changeVelocties(model, velocity, angularVelocity)

		if alpha == 1 then
			task.delay(deltaTime, function()
				if lastTweenTime ~= currentTweenTime then return end
				changeVelocties(model, Vector3.zero, Vector3.zero)
			end)
		end

		model:PivotTo(newCFrame)
	end, initialTweenInfo, RunService.PreSimulation)

	local function play(newGoalCFrame: CFrame, tweenInfo: ExtendedTweenInfo?)
		startingCFrame = model:GetPivot()
		goalCFrame = newGoalCFrame

		lastTweenTime = os.clock()
		tween.Play(0, 1, tweenInfo)
	end

	return {
		Play = play,
		Pause = tween.Pause,
		Resume = tween.Resume,
		Cancel = tween.Cancel,

		PlaybackState = tween.PlaybackState,
		Completed = tween.Completed,
	} :: PhysicsTween
end

return {
	new = new,
}
