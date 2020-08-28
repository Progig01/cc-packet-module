--Module by Progig
--Questions or suggestions? Contact me at: progig01@gmail.com

--Create the module
local m = {}

	--Handle configuration
	m.config = {}

		--configPath will load configuration settings from a file if provided for easy copy-pasting with specific settings.
		m.configPath = 'testConfig'

		--timeType controls what field fills the 'originalSendTime' of a packet:: 'disabled' for '-1' :: 'os' to use os.time()
		m.config.timeType = 'os'

		--maxBounces determines the maximum number of times a packet will be repeated by m.receive()
		m.config.maxBounces = 128

	--If configPath is not nil, load a config from a path.
	function m:loadConfig()
		if m.configPath ~= nil and fs.exists(m.configPath) then
			cFile = fs.open(m.configPath, 'r')
			data = cFile.readAll()
			m.config = textutils.unserialize(data)
			cFile.close()
		end
	end

	--Save current config to a file
	function m:saveConfig(override)
		if fs.exists(m.configPath) and not override then
			--Interfacey stuff
			print("WARNING: Attempting to save configuration over existing configuration file.")
			print("---------------------------------------------------")
			print("(This check can be disabled via function arguments)")
			print("---------------------------------------------------")
			print("")
			write("Overwrite configuration? (y/n): ")
			response = io.read()
			print("")
			
			--Handle input, respond accordingly.
			if response == 'y' or response == 'yes' or response == '1' or response == 'true' then
				cFile = fs.open(m.configPath, 'w')
				cFile.write(textutils.serialize(m.config))
				cFile.close()
				print("Configuration successfully overridden")
			elseif response == 'n' or response == 'no' or response == '0' or response == 'false' then
				print("Aborting save.")
			else
				print("Invalid response, please try again.")
			end
		else
			cFile = fs.open(m.configPath, 'w')
			cFile.write(textutils.serialize(m.config))
			cFile.close()
		end
	end

	--Get time for packet generation based on m.config.timeType, built to be extensible in case you want to add http calls or a time server computer.
	function m:getTime()
		local time = nil

		--You can edit this function to insert your own method of time-acquisition
		if m.config.timeType == 'os'       then time = os.clock() end
		if m.config.timeType == 'disabled' then time = -1        end

		return time
	end

	--Find modem, open it, return which side its on
	function m:openRednet(suppress)
		--Use argument variable or default it if not provided
		suppress = suppress or false
		
		--Make some function variables. Couldn't think of a better way to do sides.
		sides = {"top", "bottom", "front", "back", "left", "right"}
		modemSide = nil
		
		--You'll see this a lot, these are messages to print to screen if suppress isn't enabled.
		if not suppress then print("Attempting to find attached modem...") end

		--Check all the sides for a peripheral of type 'modem'
		for i=1, #sides do 
			if peripheral.getType(sides[i]) == "modem" then
				if not suppress then print("Found modem on " .. sides[i] .. " side...") end
				modemSide = sides[i]
			if not suppress then print("Checking if modem is enabled...") end
				if rednet.isOpen(modemSide) then
				if not suppress then print("Modem already opened.") end
				break
			else
				if not suppress then print("Modem closed, opening...") end
				rednet.open(modemSide)
				break
			end
			
			--If you saw this message, attach a modem c:
			else
				if not suppress then print("No modem found, please attach a modem and try again") end
				sleep(1.5)
				error("No attached modem found")
			end
		end
		
		--Returns what side the modem was on, just in case you need it in your program.
		return modemSide
	end

	--Utility function to check if a packet is validly formed
	function m:isValidPacket(p, crash)
		--If run with crash=true, will error the program if a checked packet is invalid.
		local crash = crash or false

		--Clunky, but ensures a packet has all the required fields.

			if 

			type(p) 				== 'table' and 
			p.type 					~= nil and
			p.priority 				~= nil and
			p.requiresHandshake 	~= nil and
			p.data 					~= nil and
			p.originalSenderID 		~= nil and
			p.originalSenderLabel	~= nil and
			p.originalSendTime		~= nil and
			p.destination			~= nil and
			p.delivered				~= nil and
			p.bounces				~= nil and
			p.routeTable			~= nil then

				return true
			elseif crash then
				error("Malformed or invalid packet, aborting.")
			else
				return false
			end
	end

	--Utility function to see if a computers ID is already on a given packets routing table.
	function m:alreadyRouted(p ,id)
		--Set id to this computers ID if none is provided
		id = id or os.getComputerID()

		--Check the routing table to see if given ID is already present
		for i=1, #p.routeTable do
			if p.routeTable[i].id == id then
				return true
			end
			return false
		end
	end

	--Receive a serialized packet, unserialize it, validity check it, attach functions to it.
	function m:receive(timeout, filtered, field, filter, automaticRepeating)
		--Set argument variables to defaults if not provided
		local timeout				= timeout				or 0			--Number of seconds to wait for a packet before timing out. 0 to disable
		local filtered 				= filtered 				or false		--If set to true, will only return a packet that meets filtering conditions
		local field 				= field 				or 'type'		--For use with 'filtered'; chooses what field to filter
		local filter 				= filter 				or 'generic'	--For use with 'filtered'; chooses what term to filter for
		local automaticRepeating 	= automaticRepeating 	or true			--If set to true, this machine will automatically repeat received packets if conditions are met

		--Internal use variables
		local received 		= false
		local matchesFilter = false
		local alreadyRouted = false
		local timerID = nil

		--Loop until a valid packet that meets filtering conditions comes in
		while not received do
			--If timeout is enabled, start a timer here
			if timeout > 0 then
				timerID = os.startTimer(timeout)
			end

			local event, id, _, senderID, rawMessage, transmissionDistance = os.pullEvent()

			--If event is modem_message, go on, otherwise ignore it and wait for another.
			if event == "modem_message" then
				--Unserialize the message if possible, otherwise throw it out and try again
				local p = rawMessage.message
				p = textutils.unserialize(p) 
				if p ~= nil then
					--Check to see if the unserialized table is a valid packet, if not throw it out and try again
					if m:isValidPacket(p, false) then
						--Attach internal functions to the packet
						setmetatable(p, self.pFunctionMeta)

						--Check if packet meets filtering conditions, and set matchesFilter to reflect
						if filtered then
							if p[field] == filter then
								matchesFilter = true
							end
						else
							matchesFilter = true
						end

						--Add this machine to the packets routing table
						if not m:alreadyRouted(p) then
							p:appendRouteData(nil, transmissionDistance)
						else
							alreadyRouted = true
						end

						--If packet has a specific destination check if it's eligible to be repeated
						if not alreadyRouted and p.bounces < m.config.maxBounces then
							--If this computer is the destination computer, set packets 'delivered' field to true, do not repeat.
							if p.destination > -1 and p.destination == os.getComputerID() then
								p.delivered = true
							else
							--If packet is eligible for repeating and this machine is not the destination, repeat the packet.
								p:repeatPacket(transmissionDistance)
							end
						end

						--If packet meets filtering conditions, return the packet and stop receiving.
						if matchesFilter then
							return p
						end

					end
				end
			elseif event == "timer" and timerID == id then
				return false
			end
		end
	end

	--Make a table of all 'internal' functions for packets
	local pFunctions = {}

		--A simple test function
		function pFunctions:test()
			print(self.data)
		end

		--Internal version of m:isValidPacket for convenience
		function pFunctions:isValid(crash)
			--Just call the external version of the function :)
			return m:isValidPacket(self, crash)
		end

		--Generates valid route data from the current machine,pass in transmission distance or it will default to 0
		function pFunctions:generateRouteData(d)
			local routeData = {}

			routeData.id 		= os.getComputerID()
			routeData.label 	= os.getComputerLabel() or '?'
		 	routeData.distance 	= d or 0

		   	return routeData
		end

		--Appends given route data to the packet
		function pFunctions:appendRouteData(rD, d)
			--Sets distance to 0 if not passed in.
			local d = d or 0
			local rD = rD or self:generateRouteData(d)

			table.insert(self.routeTable, rD)
		end

		--Prints the route table of the packet to the screen.
		function pFunctions:printRouteTable()
			--Internal variables.
			local totalDistance = 0

			for i=1, #self.routeTable do
				totalDistance = totalDistance + self.routeTable[i].distance
				print(self.routeTable[i].id .. " : " ..  self.routeTable[i].label .. " > " .. self.routeTable[i].distance)
			end
			print("Total bounces: " .. self.bounces .. ", Total transmission distance: " .. totalDistance)
		end

		--A friendly internal way to check if a packet matches a filter.
		function pFunctions:matchesFilter(field, filter)
			if self[field] == filter then
				return true
			else
				return false
			end
		end

		--Send a packet off into the void.
		function pFunctions:send()
			if rednet.isOpen() then
				local sP = textutils.serialize(self)
				rednet.broadcast(sP)
			else
				error("Attempt to broadcast with no open Rednet connection.")
			end
		end

		--Repeats a packet, automatically appending route data
		function pFunctions:repeatPacket(d)
			self.bounces = self.bounces + 1
			self:send()
		end

	--Make a table of all 'internal' functions for clusters
	local cFunctions = {}

		--Simple test function
		function cFunctions:test()
			print('test function')
		end

		--Add a packet to the cluster
		function cFunctions:addPacket(p, crash)
			local crash = crash or false

			if p ~= nil and m:isValidPacket(p) then
				table.insert(self.packets, p)
				return true
			else
				return false
			end
		end

		--Receive a single packet to the cluster
		function cFunctions:receivePacket(timeout, filtered, field, filter, automaticRepeating)
			--Take function arguments or set defaults it not provided
			local timeout				= timeout or 0
			local filtered 				= filtered or false
			local field 				= field or 'type'
			local filter 				= filter or 'generic'
			local automaticRepeating 	= automaticRepeating or true

			--Call m:receive and append the packet into the cluster
			local rP = m:receive(timeout, filtered, field, filter, automaticRepeating)
			self:addPacket(rP, false)
			return rP, true
		end

		--Receive bulk packets to the cluster. Receives until a packet takes too long (timeout) or receives the expected amount
		function cFunctions:receiveBulkPackets(number, timeout, filtered, field, filter, automaticRepeating)
			--Take function arguments or set defaults if not provided
			local number				= number or 1
			local timeout 				= timeout or 5
			local filtered 				= filtered or false
			local field 				= field or 'type'
			local filter 				= filter or 'generic'
			local automaticRepeating 	= automaticRepeating or true

			--Loop cFunctions:receivePacket until conditions are met (timeout or number to receive)
			local packetsReceived = 0
			local receivedPacket = nil

			for i=1, number do
				receivedPacket, success = self:receivePacket(timeout, filtered, field, filter, automaticRepeating)
				packetsReceived = i
				if not success then return false, packetsReceived end
			end
			return true, packetsReceived

		end


	--Store function metatables for packets and clusters to avoid making a ton of tables at execution
	m.pFunctionMeta = {__index = pFunctions}
	m.cFunctionMeta = {__index = cFunctions}

	--Make a new packet
	function m:newPacket(type, priority, requiresHandshake, data)
		local p = {}

		--Add all default keys to the packet, and set defaults for un-provided arguments
		p.type     				= type 					or 'generic'	--You can make this whatever you want.
		p.priority 				= priority 				or '5'				--You can make this whatever you want.
		p.requiresHandshake 	= requiresHandshake 	or false			--Determines if the packet needs to perform a handshake to ensure there is a recipient available.
		p.data 					= data 					or 'test packet'	--Data contained by the packet, can be anything, really.
		p.originalSenderID  	= os.getComputerID()	or nil				--Numeric ID of the computer that created the packet
		p.originalSenderLabel 	= os.getComputerLabel() or '?'				--Label of the computer that created the packet, defaults to '?' if none is set.
		p.originalSendTime		= m:getTime()			or nil				--Time (based on config setting) the packet was created
		p.destination			= destination 			or -1				--Numeric ID of intended destination computer, if -1 the packet has no particular intended destination.
		p.delivered				= false										--Mostly for use with p.destination, stops automatic repeating if true.
		p.bounces				= 0											--A count of the number of times the packet has been automatically repeated.
		p.routeTable			= {{id = p.originalSenderID, label = p.originalSenderLabel, distance = 0}}

		return setmetatable(p, self.pFunctionMeta)
	end

	--Make a cluster of packets for easy management and organization.
	function m:newCluster()
		local c = {}

		c.packets = {}

		return setmetatable(c, self.cFunctionMeta)
	end

--Return the module
return m
