--test_scheduler.lua
package.path = package.path..";../?.lua"

local Kernel = require("schedlua.kernel")

local function task0()
  print(getCurrentTaskID());
	print("zero task")
end

local function task1()
  print(getCurrentTaskID());
	print("first task")
end

local function task2()
  print(getCurrentTaskID());
	print("second task")
end

local function task3()
  print(getCurrentTaskID());
	print("third task")
end

local function task4()
  print(getCurrentTaskID());
	print("fourth task")
end

local function task5()
  print(getCurrentTaskID());
	print("fifth task")
end

local function taskEnd()
  print(getCurrentTaskID());
	print("Stop!")
  halt();
end


local function main()
	local t0 = coop(8, task0)
	local t1 = coop(4, task1)
	local t2 = coop(3, task2)
	local t3 = coop(7, task3)
  local t4 = coop(5, task4)
  local t5 = coop(1, task5)
  local tStop = coop(20, taskEnd)
end

run(main)

print("After kernel run...")
