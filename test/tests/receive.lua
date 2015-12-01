EXPORT_ASSERT_TO_GLOBALS = true

local luaunit   = require "luaunit"
local dpdk      = require "dpdk" -- TODO: rename dpdk module to "moongen"
local memory	= require "memory"
local device	= require "device"
local timer 	= require "timer"

package.path 	= package.path .. ";../tconfig.lua"
local tconfig   = require "tconfig"

local PKT_SIZE  = 60 -- without CRC

TestSend = {}

    function master()
	local testPairs = tconfig.pairs()
    
        local testDevs = {}
		for i, v in ipairs(testPairs) do
			testDevs[i][1] = device.config{ port = testPorts[i][1], rxQueues = 2, txQueues = 3 }
			testDevs[i][2] = device.config{ port = testPorts[i][2], rxQueues = 2, txQueues = 3 }
		end
        device.waitForLinks()

		for i = 1, #testPorts do
			TestSend["testNic" .. testPorts[i]] = function()
				sendSlave( testDevs[i][1], testDevs[i][2] )
                luaunit.assertTrue( receiveSlave( testDevs[i][2] ) )
            
				sendSlave( testDevs[i][2], testDevs[i][1] )
                luaunit.assertTrue( receiveSlave( testDevs[i][1] ) )
			end
		end
		os.exit( luaunit.LuaUnit.run() )
    end

    function sendSlave(dev, target)
        local queue = dev:getTxQueue(0)
        local tqueue = target:getTxQueue(0)
        dpdk.sleepMillis(100)
    
        local mem = memory.createMemPool(function(buf)
            buf:getEthernetPacket():fill{
                pktLength = PKT_SIZE,
                ethSrc = queue, --random src
                ethDst = tqueue, --random dst
            }
        end)
    
        local bufs = mem:bufArray()
        local runtime = timer:new(10)
        while runtime:running() and dpdk.running() do
            bufs:alloc(PKT_SIZE)
            queue:send(bufs)
        end
    
        return 1 -- Test Successful
    end

    function receiveSlave(dev)
        print("Testing Receive Capability: ", dev)
    
        return 1
    end


