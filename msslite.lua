local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local StoreLazyLoader = {}
function StoreLazyLoader:init()
	local stores = {}

	function StoreLazyLoader:Add(key, store)
		key = tostring(key)
		if not store then
			store = MemoryStoreService:GetHashMap(key)
		end
		stores[key] = store
		print("Store lazy-loaded... Current stores:")
		print(stores)
		return stores[key]
	end

	function StoreLazyLoader:Get(key)
		return stores[tostring(key)]
	end

	function StoreLazyLoader:Remove(key)
		stores[tostring(key)] = nil
	end

	function StoreLazyLoader:RemoveAll()
		stores = {}
	end

	function StoreLazyLoader:GetAllCopy()
		return deepCopy(stores)
	end
end
StoreLazyLoader:init()

local function CopyTable(t)
	local success, result = pcall(function()
		return HttpService:JSONDecode(HttpService:JSONEncode(t))
	end)
	if not success then
		warn("Failed to deep copy table: " .. tostring(result))
		return nil
	end
	return result
end

-- MemoryStoreServiceLite (MSSLite)
local function MSSLite(memoryStore)
	local msmod = {}
	local MemoryStore = memoryStore
	local cache = nil
	local entryKey = nil

	function msmod:InitStore(key)
		print("Initializing store: " .. key)
		if not MemoryStore then
			MemoryStore = StoreLazyLoader:Add(key)
			return self
		end
		print("Use MSSLite:ReleaseStore() before initializing a new store")
		return self
	end

	function msmod:SetStore(memoryStore)
		MemoryStore = memoryStore
	end

	function msmod:GetStore()
		return MemoryStore
	end

	function msmod:ReleaseStore()
		if MemoryStore then
			MemoryStore = nil
			return true
		end
		print("No MemoryStore to release")
		return false
	end

	function msmod:GetData(key)
		local success, result = pcall(function()
			return MemoryStore:GetAsync(key)
		end)
		if not success then
			warn(result)
		end
		return success, result
	end

	function msmod:GetCacheCopy()
		if type(cache) ~= "table" then
			return cache
		end
		return CopyTable(cache)
	end

	function msmod:LoadIntoCache(key)
		print("Loading key into cache: " .. tostring(key))
		entryKey = key
		local success
		success, cache = self:GetData(key)
		print("Cache load success: " .. tostring(success))
		return success
	end

	function msmod:SaveData(key, data, expiration)
		local success, result = pcall(function()
			return MemoryStore:SetAsync(key, data, expiration or 60)
		end)
		if not success then
			warn(result)
		end
		return success, result
	end

	function msmod:ReleaseCache()
		cache = nil
		entryKey = nil
		return true
	end

	function msmod:SaveCache(expiration)
		return self:SaveData(entryKey, cache, expiration)
	end

	function msmod:SaveCacheToEntry(key, expiration)
		return self:SaveData(key, cache, expiration)
	end

	function msmod:SaveAndReleaseCache()
		self:SaveCache()
		self:ReleaseCache()
	end

	function msmod:SaveCacheAndReleaseFull()
		self:SaveAndReleaseCache()
		self:ReleaseStore()
	end

	function msmod:UpdateCache(newData, ...)
		if type(cache) ~= "table" then
			cache = newData
			print("Cache updated directly to: " .. tostring(newData))
			return true
		end

		local function update(t, newData, ...)
			print("Searching for key " .. (...) .. " in:")
			print(t)
			if type(t) == "table" then
				if t[(...)] then
					print((...) .. " found in cache")
					if select('#', ...) == 1 then
						print("Updating value for key: " .. ((...)))
						t[(...)] = newData
						return true
					else
						return update(t[(...)], newData, select(2, ...))
					end
				else
					return false
				end
			end
			return false
		end

		return update(cache, newData, ...)
	end

	function msmod:GetCachedStore(key)
		return StoreLazyLoader:Get(key)
	end

	function msmod:LazyLoadStore(key)
		if not StoreLazyLoader:Get(key) then
			self:InitStore(key)
		end
		return StoreLazyLoader:Get(key)
	end

	function msmod:GetCachedStores()
		return StoreLazyLoader:GetAllCopy()
	end

	return msmod
end

return MSSLite
