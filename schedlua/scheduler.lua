
local ffi = require("ffi");

local Queue = require("schedlua.queue")
local Task = require("schedlua.task");

print("== SCHEDULER INCLUDED==")

--[[
	The Scheduler supports a cooperative multi-tasking
	environment.  The fundamental unit of execution is the Lua coroutine.
	Lua coroutines allow a program to rapidly switch between different coding
	contexts.  The language itself provides the simple switching mechanism, but
	does not provide a mechanism to organize these various tasks, which means there
	are no guarantees in terms of fairness, nor organizing principles to ensure any
	particular model or multi-tasking.  The scheduler provides a mechanism by which
	work can be organized and executed in a manner that provides coherence to a larger
	application.

	The scheduler is of primary benefit which it is managing hundreds, if not
	thousands of tasks which intend to execute concurrently.

	Work that is to be performed is encapsulated in a 'task' object.  The task object
	contains the entirety of the context related to a particular task.  This is the 
	parameters that were used to begin execution, as well as a reference to the function
	that is actually to be run to perform the task.

	The scheduler works by maintaining a 'ReadyList', which are the tasks which
	are ready to receive some compute cycles.  Tasks are added to the list by
	calling the scheduler's 'scheduleTask()' function.

	Putting a task on the ready list does not cause it to execute immediately.  It
	is just an indicator that at some point in the future this task will execute.

	Which task is to execute next is determined in the scheduler's 'step()' function.
	Here, the schedulers task picking routine (first in first out) pulls the next 
	task out of the ReadyList, and resumes it.

	A task will run until it explicitly calls 'yield()', or yields implicitly by 
	performing an operation that in turn calls yield.

	This scheduler is fairly simple, and will be appropriate for many relatively
	simple cooperative multi-tasking environments.  In cases where a different
	policy of fairness is required, a different scheduler might be more appropriate.

	The scheduler is implemented as an object, and you must create an instance of
	it to be used in your application.  This allows for the possibility of
	maintaining multiple different schedulers within the same Lua state.  It is
	not likely that this will be a highly used featured, but the possibility exists.
--]]
local Scheduler = {}
setmetatable(Scheduler, {
	__call = function(self, ...)
		return self:new(...)
	end,
})
local Scheduler_mt = {
	__index = Scheduler,
}

function Scheduler.init(self, ...)
	local obj = {
		TasksReadyToRun = Queue();
	}
	setmetatable(obj, Scheduler_mt)
	
	return obj;
end

function Scheduler.new(self, ...)
	return self:init(...)
end

--[[
		Instance Methods
--]]
--[[
	tasksPending

	A simple method to let anyone know how many tasks are currently
	on the ready to run list.

	This might be useful when you're running some predicate logic based 
	on how many tasks there are.
--]]
function Scheduler.tasksPending(self)
	return self.TasksReadyToRun:length();
end


--[[
	Task Handling
--]]

-- put a task on the ready list
-- the 'task' should be something that can be executed,
-- whether it's a function, functor, or something that has a '__call'
-- metamethod implemented.
-- The 'params' is a table of parameters which will be passed to the function
-- when it's ready to run.
function Scheduler.scheduleTask(self, task, params, priority)
	--print("Scheduler.scheduleTask: ", task, params)
	params = params or {}
	
	if not task then
		return false, "no task specified"
	end
	-- this is totally screwy to me - "priority" is nill everywhere, but "Priority" holds the appropriate value. I changed "if priority" to "if task.Priority" and it works now, but i have no idea why
	task:setParams(params);
	if task.Priority == 0 then
		--print("if: ", task.Priority);
		self.TasksReadyToRun:pushFront(task);	
	else
		--print("else: ", task.Priority);
		self.TasksReadyToRun:enqueue(task);	
	end

	task.state = "readytorun"
	return task;
end

function Scheduler.removeTask(self, task)
	--print("REMOVING DEAD TASK: ", task);
	return true;
end

function Scheduler.getCurrentTask(self)
	return self.CurrentFiber;
end

function Scheduler.suspendCurrentTask(self, ...)
	self.CurrentFiber.state = "suspended"
end

function Scheduler.step(self)
	-- Now check the regular fibers
	local task = self.TasksReadyToRun:dequeue()
	--print("task in step: ", priority);

	-- If no fiber in ready queue, then just return
	if task == nil then
		--print("Scheduler.step: NO TASK")
		return true
	end

	if task:getStatus() == "dead" then
		self:removeTask(task)

		return true;
	end

	-- If the task we pulled off the active list is 
	-- not dead, then perhaps it is suspended.  If that's true
	-- then it needs to drop out of the active list.
	-- We assume that some other part of the system is responsible for
	-- keeping track of the task, and rescheduling it when appropriate.
	if task.state == "suspended" then
		--print("suspended task wants to run")
		return true;
	end

	-- If we have gotten this far, then the task truly is ready to 
	-- run, and it should be set as the currentFiber, and its coroutine
	-- is resumed.
	self.CurrentFiber = task;
	local results = {task:resume()};

	-- once we get results back from the resume, one
	-- of two things could have happened.
	-- 1) The routine exited normally
	-- 2) The routine yielded
	--
	-- In both cases, we parse out the results of the resume 
	-- into a success indicator and the rest of the values returned 
	-- from the routine
	--local pcallsuccess = results[1];
	--table.remove(results,1);

	local success = results[1];
	table.remove(results,1);

	--print("PCALL, RESUME: ", pcallsuccess, success)

	-- no task is currently executing
	self.CurrentFiber = nil;


	if not success then
		print("RESUME ERROR")
		print(unpack(results));
	end

	-- Again, check to see if the task is dead after
	-- the most recent resume.  If it's dead, then don't
	-- bother putting it back into the readytorun queue
	-- just remove the task from the list of tasks
	if task:getStatus() == "dead" then
		self:removeTask(task)

		return true;
	end

	-- The only way the task will get back onto the readylist
	-- is if it's state is 'readytorun', otherwise, it will
	-- stay out of the readytorun list.
	if task.state == "readytorun" then
		self:scheduleTask(task, results);
	end
end



return Scheduler
