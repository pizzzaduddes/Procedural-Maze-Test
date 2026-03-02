--[[ 
	Maze Generation Script (Server-side)
	Logic: Perfect Maze Generator using DFS (recursive backtracking)
	Features:
	- Logical NxN grid
	- DFS-based generation (guarantees one unique path between any two points)
	- Entrance & exit
	- Regeneration via RemoteEvent
	- Rendering of walls & floor in Roblox workspace
--]]

local Maze = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RegenerateEvent = ReplicatedStorage:WaitForChild("RegenerateMaze") -- RemoteEvent to trigger regeneration

--[[ CONFIGURATION ]]
Maze.SIZE = 13              -- Maze is SIZE x SIZE cells
Maze.CELL_SIZE = 10         -- Size of each cell in studs (affects rendering)
Maze.WALL_HEIGHT = 5        -- Wall height for visualization
Maze.SEED = os.time()       -- Seed for deterministic/random maze generation
Maze.MODEL = nil            -- Container for all maze parts, allows easy cleanup

--[[ RUNTIME STATE ]]
Maze.Grid = {}              -- Logical representation of maze (cells with wall flags)
Maze.Stack = {}             -- DFS stack, tracks path for backtracking

--[[ INITIALIZATION ENTRY POINT ]]
function Maze:Initialize()
	math.randomseed(self.SEED) -- Seed RNG for reproducibility

	-- Step 1: Build the logical grid (NxN cells with walls intact)
	self:CreateLogicalGrid()

	-- Step 2: Generate maze connections via DFS
	self:GenerateMazeDFS()

	-- Step 3: Open entrance and exit (edges of the maze)
	self:CreateEntranceAndExit()

	-- Step 4: Render the maze in the workspace
	self:RenderMaze()
end

--[[ REGENERATION FUNCTION ]]
function Maze:Regenerate()
	-- Clear previous runtime state
	self.Grid = {}
	self.Stack = {}

	-- Use a new seed for variation
	self.SEED = os.time()
	math.randomseed(self.SEED)

	-- Re-run all steps: logical grid → DFS → entrance/exit → render
	self:CreateLogicalGrid()
	self:GenerateMazeDFS()
	self:CreateEntranceAndExit()
	self:RenderMaze()
end

--[[ SERVER LISTENER: Trigger regeneration from RemoteEvent ]]
RegenerateEvent.OnServerEvent:Connect(function(player)
	Maze:Regenerate()
end)

--[[ CREATE LOGICAL GRID ]]
function Maze:CreateLogicalGrid()
	-- Loop through each cell position
	for x = 1, self.SIZE do
		self.Grid[x] = {}

		for y = 1, self.SIZE do
			-- Each cell stores:
			-- visited: DFS marker to prevent cycles
			-- walls: boolean flags for top, right, bottom, left
			-- Initially all walls exist, meaning no connections yet
			self.Grid[x][y] = {
				visited = false,
				walls = {
					top = true,
					right = true,
					bottom = true,
					left = true
				}
			}
		end
	end
end

--[[ CHECK BOUNDS ]]
function Maze:IsInside(x, y)
	-- Ensures we never check cells outside the grid
	return x >= 1 and x <= self.SIZE and y >= 1 and y <= self.SIZE
end

--[[ GET UNVISITED NEIGHBORS ]]
function Maze:GetUnvisitedNeighbors(x, y)
	local neighbors = {}

	-- Directions represent potential moves from current cell
	local directions = {
		{dx = 0, dy = -1, dir = "top"},
		{dx = 1, dy = 0, dir = "right"},
		{dx = 0, dy = 1, dir = "bottom"},
		{dx = -1, dy = 0, dir = "left"}
	}

	for _, d in ipairs(directions) do
		local nx = x + d.dx
		local ny = y + d.dy

		-- Only consider cells that exist in the grid and are unvisited
		if self:IsInside(nx, ny) and not self.Grid[nx][ny].visited then
			-- Include direction info to remove correct walls later
			table.insert(neighbors, {
				x = nx,
				y = ny,
				dir = d.dir
			})
		end
	end

	return neighbors -- DFS will randomly pick one neighbor from this list
end

--[[ REMOVE WALL BETWEEN TWO ADJACENT CELLS ]]
function Maze:RemoveWall(x1, y1, x2, y2)
	local cell = self.Grid[x1][y1]
	local neighbor = self.Grid[x2][y2]

	-- Determine relative position to remove walls symmetrically
	if x2 == x1 and y2 == y1 - 1 then -- neighbor is above
		cell.walls.top = false
		neighbor.walls.bottom = false

	elseif x2 == x1 + 1 and y2 == y1 then -- neighbor is right
		cell.walls.right = false
		neighbor.walls.left = false

	elseif x2 == x1 and y2 == y1 + 1 then -- neighbor is below
		cell.walls.bottom = false
		neighbor.walls.top = false

	elseif x2 == x1 - 1 and y2 == y1 then -- neighbor is left
		cell.walls.left = false
		neighbor.walls.right = false
	end
end

--[[ DFS MAZE GENERATION ]]
function Maze:GenerateMazeDFS()
	-- Start at a random cell
	local startX = math.random(1, self.SIZE)
	local startY = math.random(1, self.SIZE)

	local currentX = startX
	local currentY = startY
	self.Grid[currentX][currentY].visited = true -- mark start as visited

	-- Repeat until all reachable cells are processed
	repeat
		local neighbors = self:GetUnvisitedNeighbors(currentX, currentY)

		if #neighbors > 0 then
			-- Randomly choose a neighbor to move to (adds natural randomness)
			local chosen = neighbors[math.random(1, #neighbors)]

			-- Connect current cell to chosen neighbor
			self:RemoveWall(currentX, currentY, chosen.x, chosen.y)

			-- Push current cell to stack to allow backtracking
			table.insert(self.Stack, {x = currentX, y = currentY})

			-- Move to neighbor and mark it visited
			currentX = chosen.x
			currentY = chosen.y
			self.Grid[currentX][currentY].visited = true

		elseif #self.Stack > 0 then
			-- No unvisited neighbors → backtrack
			local previous = table.remove(self.Stack)
			currentX = previous.x
			currentY = previous.y
		end

	until #self.Stack == 0 -- finished when all cells visited
end

--[[ CREATE ENTRANCE AND EXIT ]]
function Maze:CreateEntranceAndExit()
	-- Entrance on top row
	local entranceX = math.random(1, self.SIZE)
	local entranceY = 1
	self.Grid[entranceX][entranceY].walls.top = false
	self.Entrance = {x = entranceX, y = entranceY} -- store for potential gameplay use

	-- Exit on bottom row
	local exitX = math.random(1, self.SIZE)
	local exitY = self.SIZE
	self.Grid[exitX][exitY].walls.bottom = false
	self.Exit = {x = exitX, y = exitY}
end

--[[ RENDER MAZE IN WORKSPACE ]]
function Maze:RenderMaze()
	-- Clean up old maze to prevent duplicates
	if self.MODEL then
		self.MODEL:Destroy()
	end

	-- Create a container model to hold all maze parts
	self.MODEL = Instance.new("Model")
	self.MODEL.Name = "GeneratedMaze"
	self.MODEL.Parent = workspace

	-- Render each logical cell
	for x = 1, self.SIZE do
		for y = 1, self.SIZE do
			self:RenderCell(x, y)
		end
	end
end

--[[ RENDER INDIVIDUAL CELL ]]
function Maze:RenderCell(x, y)
	local cell = self.Grid[x][y]

	-- Compute world position
	local worldX = x * self.CELL_SIZE
	local worldZ = y * self.CELL_SIZE

	-- Floor part (visual base)
	local floor = Instance.new("Part")
	floor.Size = Vector3.new(self.CELL_SIZE, 1, self.CELL_SIZE)
	floor.Position = Vector3.new(worldX, 0, worldZ)
	floor.Anchored = true
	floor.Parent = self.MODEL -- parent to maze container

	-- Conditionally render walls based on logical flags
	if cell.walls.top then
		self:CreateWall(worldX, worldZ - self.CELL_SIZE/2)
	end

	if cell.walls.right then
		self:CreateWall(worldX + self.CELL_SIZE/2, worldZ, true)
	end

	if cell.walls.bottom then
		self:CreateWall(worldX, worldZ + self.CELL_SIZE/2)
	end

	if cell.walls.left then
		self:CreateWall(worldX - self.CELL_SIZE/2, worldZ, true)
	end
end

--[[ CREATE INDIVIDUAL WALL PART ]]
function Maze:CreateWall(x, z, vertical)
	local wall = Instance.new("Part")

	-- Decide wall orientation: vertical or horizontal
	if vertical then
		wall.Size = Vector3.new(1, self.WALL_HEIGHT, self.CELL_SIZE)
	else
		wall.Size = Vector3.new(self.CELL_SIZE, self.WALL_HEIGHT, 1)
	end

	wall.Position = Vector3.new(x, self.WALL_HEIGHT/2, z)
	wall.Anchored = true
	wall.Parent = self.MODEL -- parent to maze container
end

--[[ START MAZE GENERATION ON SERVER STARTUP ]]
Maze:Initialize()
