-- Prism Nametag System (Supabase + auto-spritesheet edition)
-- Paste a spritesheet URL into Supabase → the script auto-detects the grid
-- and animates frame-by-frame. No grid columns required.
--
-- SPRITESHEET FIX: playback no longer uses ImageRectOffset/ImageRectSize.
-- Roblox downscales large images, which made the rect offsets drift downward.
-- The sheet is now stretched to (cols x rows) tag-sizes and moved with
-- Position, which is resolution independent.
--
-- ALL-SHEET FIX: every spritesheet URL is routed through wsrv.nl with
-- output=png&il=0, exactly like the cat.png link. That gives Roblox (and the
-- pixel analyzer) a clean, non-interlaced PNG no matter what the source
-- format was, and the grid is transposed so playback always goes left→right
-- like a GIF. If detection fails, the sheet is shown as a static image
-- instead of sliding around broken.

local PrismNametags = {}

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")

local PM = getgenv().PrismMain
local C = PM and PM.C or {
    bg = Color3.fromRGB(15, 15, 15),
    card = Color3.fromRGB(28, 28, 28),
    accent = Color3.fromRGB(180, 180, 180),
    text = Color3.fromRGB(230, 230, 230),
    textDim = Color3.fromRGB(90, 90, 90),
    border = Color3.fromRGB(45, 45, 45),
    sep = Color3.fromRGB(60, 60, 70),
}

local function tween(obj, time, props, style)
    return TweenService:Create(obj, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quad), props):Play()
end

local httprequest       = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
local waxgetcustomasset = getcustomasset or getsynasset

-- ============================================================
-- SUPABASE
-- ============================================================
local SUPABASE = {
    url        = "https://cepueimpcwhbgjvxcuye.supabase.co",
    anonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlcHVlaW1wY3doYmdqdnhjdXllIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3OTM4OTEsImV4cCI6MjEwNjM2OTg5MX0.HAp28aFMFIgezw5Rthv87tE8JT-8HJMgPyqRYdMW8Ac",
    usersTable = "prism_users",
    tagsTable  = "prism_nametags",
    autoSyncInterval = 3,
}

local function supabaseRequest(method, path, body, extraHeaders)
    if not httprequest then return nil, "no HTTP function" end
    local headers = {
        ["apikey"]        = SUPABASE.anonKey,
        ["Authorization"] = "Bearer " .. SUPABASE.anonKey,
        ["Content-Type"]  = "application/json",
        ["Accept"]        = "application/json",
        ["Cache-Control"] = "no-cache, no-store, max-age=0",
        ["Pragma"]        = "no-cache",
    }
    if extraHeaders then
        for k, v in pairs(extraHeaders) do headers[k] = v end
    end
    local req = { Url = SUPABASE.url .. "/rest/v1/" .. path, Method = method, Headers = headers }
    if body ~= nil then req.Body = HttpService:JSONEncode(body) end
    local ok, res = pcall(httprequest, req)
    if not ok then return nil, tostring(res) end
    local status   = res.StatusCode or res.status or 200
    local respBody = res.Body or res.body or ""
    if status >= 400 then return nil, respBody end
    if respBody == "" then return {} end
    local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, respBody)
    if decodeOk then return data end
    return nil, "decode error"
end

local function supabaseGet(path) return supabaseRequest("GET", path) end

local function registerUser(uid, uname, dname, jobid, gname)
    return supabaseRequest("POST", SUPABASE.usersTable .. "?on_conflict=user_id",
        { user_id=uid, username=uname, display_name=dname, job_id=jobid,
          game_name=gname, last_seen=DateTime.now():ToIsoDate() },
        { ["Prefer"] = "resolution=merge-duplicates,return=minimal" })
end

local function ensureNametagRow(uid, uname, dname)
    -- Only create the row if it does not exist yet.
    -- IMPORTANT: do not merge/overwrite an existing row here, otherwise any
    -- username/display-name edits made in Supabase get reset every autosync.
    return supabaseRequest("POST", SUPABASE.tagsTable .. "?on_conflict=user_id",
        { user_id=uid, username=uname, display_name=dname },
        { ["Prefer"] = "resolution=ignore-duplicates,return=minimal" })
end

local function deleteUserRow(uid)
    return supabaseRequest("DELETE",
        SUPABASE.usersTable .. "?user_id=eq." .. tostring(uid),
        nil, { ["Prefer"] = "return=minimal" })
end

-- ============================================================
-- FILE REGISTRY (kavrenoo fallback)
-- ============================================================
PrismNametags.FileRegistry = { nametags = {} }

for i = 0, 22 do
    PrismNametags.FileRegistry.nametags["kavrenoo_frame" .. i] = {
        url  = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_" .. i .. ".png",
        path = "prism/nametags/Kavrenoo/frame_" .. i .. ".png",
    }
end

PrismNametags.NAMETAG_CONFIG = {
    kavrenoo = {
        userIds           = {7275889224, 5712636024},
        imagePath         = nil,
        borderColor       = Color3.fromRGB(255, 255, 255),
        gradientColor     = Color3.fromRGB(255, 255, 255),
        gradientSpinColor = Color3.fromRGB(245, 245, 245),
        typingText        = "Owner",
        distanceLabel     = "P",
        isAnimated        = true,
        frameBasePath     = "prism/nametags/Kavrenoo/frame_",
        frameCount        = 23,
        frameTime         = 0.1,
    },
}

-- ============================================================
-- CACHES
-- ============================================================
local remoteConfigs     = {}
local appliedSignatures = {}
local assetCache        = {}
local spriteMetaCache   = {}
local configCache       = {}

local SIGNATURE_FIELDS = {
    "enabled",
    "background_image", "background_color", "border_color",
    "gradient_color", "gradient_spin_color", "text_color", "username_color",
    "display_name", "username", "display_name_override", "username_override",
    "show_display_name", "show_username",
    "username_prefix", "typing_text", "distance_label", "font",
    "text_size", "username_size", "nametag_width", "nametag_height",
    "spritesheet_url", "spritesheet_columns", "spritesheet_rows",
    "spritesheet_frame_width", "spritesheet_frame_height",
    "spritesheet_frame_time", "spritesheet_frames",
    "frame_urls", "frame_folder", "frame_time",
}

local function rowSignature(row)
    if not row then return "" end
    local parts = {}
    for i = 1, #SIGNATURE_FIELDS do parts[i] = tostring(row[SIGNATURE_FIELDS[i]]) end
    return table.concat(parts, "|")
end

local function safeFont(name, fallback)
    if not name or name == "" then return fallback end
    local ok, f = pcall(function() return Enum.Font[name] end)
    if ok and f then return f end
    return fallback
end

local function hexToColor3(hex)
    if not hex or hex == "" then return nil end
    hex = tostring(hex):gsub("#", "")
    if #hex ~= 6 then return nil end
    return Color3.fromRGB(
        tonumber(hex:sub(1,2), 16) or 0,
        tonumber(hex:sub(3,4), 16) or 0,
        tonumber(hex:sub(5,6), 16) or 0)
end

local function hashString(s)
    local h = 5381
    for i = 1, #s do h = ((h * 33) + s:byte(i)) % 0x7FFFFFFF end
    return string.format("%x", h)
end

local function getAsset(path)
    if not path or path == "" then return nil end
    if assetCache[path] then return assetCache[path] end
    if not waxgetcustomasset then return nil end
    local ok, asset = pcall(waxgetcustomasset, path)
    if ok and asset then
        assetCache[path] = asset
        return asset
    end
    return nil
end

-- Roblox can only load PNG/JPEG from getcustomasset. Anything else (an HTML
-- 404 page, a WebP/GIF from a proxy, an empty body) gets rejected here so it
-- is never saved or cached as if it were a valid image.
local function detectImageKind(data)
    if type(data) ~= "string" or #data < 12 then return nil, "empty response" end
    if data:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
    if data:sub(1, 3) == "\255\216\255" then return "jpg" end
    if data:sub(1, 4) == "GIF8" then return nil, "GIF (Roblox cannot load GIF, use a PNG spritesheet)" end
    if data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WEBP" then return nil, "WebP (Roblox cannot load WebP)" end
    local head = data:sub(1, 60):lower()
    if head:find("<!doctype") or head:find("<html") or head:find("{") then
        return nil, "not an image (got text/HTML/JSON, likely a 404 or error page)"
    end
    return nil, "unknown file format"
end

local function urlEncode(s)
    return (tostring(s):gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

-- Hosts that already serve Roblox-friendly PNG/JPEG — try direct first.
local function prefersDirectDownload(url)
    url = tostring(url):lower()
    return url:find("raw%.githubusercontent%.com", 1, false)
        or url:find("i%.postimg%.cc", 1, false)
        or url:find("postimg%.cc", 1, false)
        or url:find("i%.imgur%.com", 1, false)
        or url:find("cdn%.jsdelivr%.net", 1, false)
        or url:find("%.png", 1, true)
        or url:find("%.jpg", 1, true)
        or url:find("%.jpeg", 1, true)
end

local function normalizeImageUrl(url)
    -- wsrv.nl re-encodes the source into a real PNG. Useful when the source
    -- is WebP/AVIF/etc. Must fully URL-encode the nested url= value or wsrv
    -- returns HTTP 400 (common with postimg / query-heavy links).
    if url:find("wsrv.nl", 1, true) then
        if not url:find("output=", 1, true) then
            url = url .. (url:find("?", 1, true) and "&" or "?") .. "output=png&il=0"
        end
        return url
    end
    return "https://wsrv.nl/?url=" .. urlEncode(url) .. "&output=png&il=0"
end

local downloadFailedAt = {}

local function downloadImageForUser(userId, url)
    if type(url) ~= "string" or url == "" then return nil end
    url = url:gsub("^%s+", ""):gsub("%s+$", "")

    -- Clean up URLs pasted as markdown, e.g.
    --   [https://site/dir/](https://site/dir/old.png)new.png
    -- The bracket text plus the trailing text is the intended URL; with no
    -- trailing text, the (target) is used.
    local mdText, mdTarget, mdRest = url:match("^%[(.-)%]%((.-)%)(.*)$")
    if mdText then
        if mdRest ~= "" then url = mdText .. mdRest else url = mdTarget end
    end
    url = url:gsub("^[%s\"'<]+", ""):gsub("[%s\"'>]+$", "")
    if not url:match("^https?://") then
        local found = url:find("https?://")
        if found then url = url:sub(found) end
    end
    if not url:match("^https?://") then
        warn("[Prism] Invalid image URL in Supabase (must start with http:// or https://): " .. tostring(url))
        return nil
    end

    -- Don't hammer a failing URL every sync; retry after 30s.
    if downloadFailedAt[url] and tick() - downloadFailedAt[url] < 30 then return nil end

    -- Build a list of URLs to try, best first:
    --  • Hosts that already serve PNG (postimg, raw GitHub, etc.) → direct first
    --  • Otherwise → wsrv.nl (fully encoded) then direct fallback
    local candidates, seen = {}, {}
    local function addCandidate(u)
        if u and u ~= "" and not seen[u] then seen[u] = true; candidates[#candidates + 1] = u end
    end
    local directFirst = prefersDirectDownload(url)
    if directFirst then
        addCandidate(url)
        addCandidate(normalizeImageUrl(url))
    else
        addCandidate(normalizeImageUrl(url))
        addCandidate(url)
    end
    if url:find("wsrv.nl", 1, true) then
        local inner = url:match("[?&]url=([^&]+)")
        if inner then
            inner = inner:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            if not inner:match("^https?://") then inner = "https://" .. inner end
            addCandidate(inner)
        end
    end

    local folder = "prism/nametags/supabase/user_" .. tostring(userId)
    if makefolder and not isfolder(folder) then pcall(makefolder, folder) end
    -- Cache key is the URL as stored, so it stays stable across candidates.
    local base = folder .. "/" .. hashString(url)

    -- Reuse a previously downloaded file, but only if it is a real image.
    for _, ext in ipairs({ ".png", ".jpg" }) do
        local cached = base .. ext
        if isfile and isfile(cached) then
            local okRead, existing = pcall(readfile, cached)
            if okRead and detectImageKind(existing) then return cached end
            pcall(delfile, cached) -- bad cache from an earlier failed download
        end
    end

    for _, tryUrl in ipairs(candidates) do
        local data, status
        if httprequest then
            local ok, r = pcall(httprequest, { Url = tryUrl, Method = "GET" })
            if ok and r then
                data   = r.Body or r.body
                status = r.StatusCode or r.status
            else
                warn("[Prism] Image request errored: " .. tostring(r))
            end
        else
            local ok, r = pcall(function() return game:HttpGet(tryUrl) end)
            if ok then data = r end
        end

        if status and (status < 200 or status >= 300) then
            warn(("[Prism] Image download failed: HTTP %s for %s"):format(tostring(status), tryUrl))
        else
            local kind, reason = detectImageKind(data)
            if not kind then
                warn(("[Prism] Not a usable image: %s (URL: %s)"):format(tostring(reason), tryUrl))
            else
                local path = base .. "." .. kind
                if pcall(function() writefile(path, data) end) then
                    print(("[Prism] Downloaded %s (%d bytes) from %s"):format(kind, #data, tryUrl))
                    return path
                else
                    warn("[Prism] Could not write " .. path)
                end
            end
        end
    end

    downloadFailedAt[url] = tick()
    warn("[Prism] All download attempts failed for: " .. url)
    return nil
end

-- ============================================================
-- PNG HEADER PARSER  (dimensions + color type + interlace)
-- ============================================================
local function readU32BE(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    if not a then return nil end
    return a * 16777216 + b * 65536 + c * 256 + d
end

local function getPngInfo(path)
    if not isfile or not isfile(path) then return nil end
    local ok, data = pcall(readfile, path)
    if not ok or not data or #data < 33 then return nil end
    if data:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
    if data:sub(13, 16) ~= "IHDR" then return nil end
    local w = readU32BE(data, 17)
    local h = readU32BE(data, 21)
    if not w or not h or w <= 0 or h <= 0 then return nil end
    local bitDepth  = data:byte(25) or 0
    local colorType = data:byte(26) or 0
    local interlace = data:byte(29) or 0
    return {
        width = w, height = h,
        bitDepth = bitDepth,
        colorType = colorType,   -- 0=gray, 2=RGB, 3=palette, 4=gray+a, 6=RGBA
        interlace = interlace,   -- 0=non-interlaced, 1=Adam7
    }
end

-- ============================================================
-- PNG DECODER + CONTENT-BASED SPRITESHEET ANALYSIS
-- Decodes the sheet once (8-bit, non-interlaced PNG), then finds the real
-- frame grid by looking for the repeating pattern between frames, and counts
-- trailing empty cells. Result is cached on disk next to the image (.grid).
-- ============================================================
local unpackFn = table.unpack or unpack
local byteFn   = string.byte
local floorFn  = math.floor

local POW2 = {}
for i = 0, 32 do POW2[i] = 2 ^ i end

local LBASE = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local LEXT  = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local DBASE = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local DEXT  = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local CLORDER = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}

local function buildHuff(lengths, n)
    local count = {}
    for i = 0, 15 do count[i] = 0 end
    for i = 0, n - 1 do count[lengths[i]] = count[lengths[i]] + 1 end
    local offs = { [1] = 0 }
    for i = 1, 14 do offs[i + 1] = offs[i] + count[i] end
    local symbol = {}
    for i = 0, n - 1 do
        local l = lengths[i]
        if l ~= 0 then
            symbol[offs[l]] = i
            offs[l] = offs[l] + 1
        end
    end
    return { count = count, symbol = symbol }
end

local FIXED_LIT, FIXED_DIST
do
    local l = {}
    for i = 0, 143 do l[i] = 8 end
    for i = 144, 255 do l[i] = 9 end
    for i = 256, 279 do l[i] = 7 end
    for i = 280, 287 do l[i] = 8 end
    FIXED_LIT = buildHuff(l, 288)
    local d = {}
    for i = 0, 29 do d[i] = 5 end
    FIXED_DIST = buildHuff(d, 30)
end

-- Inflate `data` (a zlib stream, starting at startPos) and call onRow(row)
-- each time rowLen bytes of output have been produced.
local function inflateRows(data, startPos, rowLen, onRow)
    local pos = startPos
    local bitbuf, bitcnt = 0, 0
    local window = {}
    local wpos = 0
    local row = {}
    local rowIdx = 0

    local function bits(need)
        local val, cnt = bitbuf, bitcnt
        while cnt < need do
            local b = byteFn(data, pos)
            if not b then error("unexpected end of compressed data") end
            pos = pos + 1
            val = val + b * POW2[cnt]
            cnt = cnt + 8
        end
        bitbuf = floorFn(val / POW2[need])
        bitcnt = cnt - need
        return val % POW2[need]
    end

    local function decodeSym(h)
        local count, symbol = h.count, h.symbol
        local code, first, index = 0, 0, 0
        local bb, bc = bitbuf, bitcnt
        for len = 1, 15 do
            if bc == 0 then
                local b = byteFn(data, pos)
                if not b then error("unexpected end of compressed data") end
                pos = pos + 1
                bb, bc = b, 8
            end
            code = code + bb % 2
            bb = floorFn(bb / 2)
            bc = bc - 1
            local c = count[len]
            if code - c < first then
                bitbuf, bitcnt = bb, bc
                return symbol[index + (code - first)]
            end
            index = index + c
            first = (first + c) * 2
            code = code * 2
        end
        error("bad huffman code")
    end

    local function put(b)
        window[wpos % 32768] = b
        wpos = wpos + 1
        rowIdx = rowIdx + 1
        row[rowIdx] = b
        if rowIdx == rowLen then
            rowIdx = 0
            onRow(row)
        end
    end

    local function codes(lit, dist)
        while true do
            local sym = decodeSym(lit)
            if sym < 256 then
                put(sym)
            elseif sym == 256 then
                return
            else
                sym = sym - 256
                if sym > 29 then error("bad length symbol") end
                local len = LBASE[sym] + bits(LEXT[sym])
                local ds = decodeSym(dist)
                local d = DBASE[ds + 1] + bits(DEXT[ds + 1])
                for _ = 1, len do
                    put(window[(wpos - d) % 32768])
                end
            end
        end
    end

    while true do
        local last = bits(1)
        local btype = bits(2)
        if btype == 0 then
            bitbuf, bitcnt = 0, 0
            local len = byteFn(data, pos) + byteFn(data, pos + 1) * 256
            pos = pos + 4
            for _ = 1, len do
                put(byteFn(data, pos))
                pos = pos + 1
            end
        elseif btype == 1 then
            codes(FIXED_LIT, FIXED_DIST)
        elseif btype == 2 then
            local nlen = bits(5) + 257
            local ndist = bits(5) + 1
            local ncode = bits(4) + 4
            local lengths = {}
            for i = 0, 18 do lengths[i] = 0 end
            for i = 1, ncode do lengths[CLORDER[i]] = bits(3) end
            local lencode = buildHuff(lengths, 19)
            local idx = 0
            local all = {}
            while idx < nlen + ndist do
                local sym = decodeSym(lencode)
                if sym < 16 then
                    all[idx] = sym
                    idx = idx + 1
                else
                    local prev, rep = 0, 0
                    if sym == 16 then
                        prev = all[idx - 1]
                        rep = 3 + bits(2)
                    elseif sym == 17 then
                        rep = 3 + bits(3)
                    else
                        rep = 11 + bits(7)
                    end
                    for _ = 1, rep do
                        all[idx] = prev
                        idx = idx + 1
                    end
                end
            end
            local ll, dl = {}, {}
            for i = 0, nlen - 1 do ll[i] = all[i] end
            for i = 0, ndist - 1 do dl[i] = all[nlen + i] end
            codes(buildHuff(ll, nlen), buildHuff(dl, ndist))
        else
            error("bad deflate block type")
        end
        if last == 1 then break end
    end
end

local function bytesToString(t, n)
    local parts = {}
    local i = 1
    while i <= n do
        local j = math.min(i + 1999, n)
        parts[#parts + 1] = string.char(unpackFn(t, i, j))
        i = j + 1
    end
    return table.concat(parts)
end

local function pngInfoFromData(data)
    if type(data) ~= "string" or #data < 33 then return nil end
    if data:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
    if data:sub(13, 16) ~= "IHDR" then return nil end
    local w, h = readU32BE(data, 17), readU32BE(data, 21)
    if not w or not h or w <= 0 or h <= 0 then return nil end
    return {
        width = w, height = h,
        bitDepth = data:byte(25) or 0,
        colorType = data:byte(26) or 0,
        interlace = data:byte(29) or 0,
    }
end

local function collectPngChunks(data)
    local pos = 9
    local idat, plte, trns = {}, nil, nil
    while pos + 8 <= #data do
        local len = readU32BE(data, pos)
        local ctype = data:sub(pos + 4, pos + 7)
        if ctype == "IDAT" then
            idat[#idat + 1] = data:sub(pos + 8, pos + 7 + len)
        elseif ctype == "PLTE" then
            plte = data:sub(pos + 8, pos + 7 + len)
        elseif ctype == "tRNS" then
            trns = data:sub(pos + 8, pos + 7 + len)
        elseif ctype == "IEND" then
            break
        end
        pos = pos + 12 + len
    end
    return table.concat(idat), plte, trns
end

-- Decode to per-row strings: gRows[y] = green/gray byte per pixel,
-- aRows[y] = alpha byte per pixel (nil if the PNG has no alpha).
local function decodePngRows(data, info)
    local W, H, ct = info.width, info.height, info.colorType
    local channels = ({ [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 })[ct]
    if not channels then error("unsupported color type " .. tostring(ct)) end
    local bpp = channels
    local rowBytes = W * bpp

    local idat, plte, trns = collectPngChunks(data)
    if #idat < 3 then error("no image data") end

    local palG, palA
    if ct == 3 then
        if not plte then error("palette PNG without PLTE") end
        palG = {}
        for i = 0, floorFn(#plte / 3) - 1 do palG[i] = byteFn(plte, i * 3 + 2) end
        if trns then
            palA = {}
            for i = 0, #palG do palA[i] = byteFn(trns, i + 1) or 255 end
        end
    end
    local gOff = (ct == 2 or ct == 6) and 2 or 1
    local aOff = (ct == 4 and 2) or (ct == 6 and 4) or nil
    local hasAlpha = aOff ~= nil or palA ~= nil

    local gRows, aRows = {}, hasAlpha and {} or nil
    local prev, recon = {}, {}
    for i = 1, rowBytes do prev[i] = 0; recon[i] = 0 end
    local gTmp, aTmp = {}, {}
    local y = 0

    local function onRow(row)
        y = y + 1
        if y > H then return end
        local ft = row[1]
        if ft == 0 then
            for i = 1, rowBytes do recon[i] = row[i + 1] end
        elseif ft == 1 then
            for i = 1, rowBytes do
                local a = i > bpp and recon[i - bpp] or 0
                recon[i] = (row[i + 1] + a) % 256
            end
        elseif ft == 2 then
            for i = 1, rowBytes do recon[i] = (row[i + 1] + prev[i]) % 256 end
        elseif ft == 3 then
            for i = 1, rowBytes do
                local a = i > bpp and recon[i - bpp] or 0
                recon[i] = (row[i + 1] + floorFn((a + prev[i]) / 2)) % 256
            end
        elseif ft == 4 then
            for i = 1, rowBytes do
                local a = i > bpp and recon[i - bpp] or 0
                local b = prev[i]
                local c = i > bpp and prev[i - bpp] or 0
                local p = a + b - c
                local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
                local pr
                if pa <= pb and pa <= pc then pr = a elseif pb <= pc then pr = b else pr = c end
                recon[i] = (row[i + 1] + pr) % 256
            end
        else
            error("bad PNG filter type " .. tostring(ft))
        end

        if ct == 3 then
            for x = 1, W do
                local idx = recon[x]
                gTmp[x] = palG[idx] or 0
                if palA then aTmp[x] = palA[idx] or 255 end
            end
        else
            local base = gOff
            for x = 1, W do
                gTmp[x] = recon[base]
                base = base + bpp
            end
            if aOff then
                local ab = aOff
                for x = 1, W do
                    aTmp[x] = recon[ab]
                    ab = ab + bpp
                end
            end
        end
        gRows[y] = bytesToString(gTmp, W)
        if hasAlpha then aRows[y] = bytesToString(aTmp, W) end

        prev, recon = recon, prev
        if y % 24 == 0 then task.wait() end
    end

    inflateRows(idat, 3, rowBytes + 1, onRow)
    if y < H then error("image data ended early (" .. y .. "/" .. H .. " rows)") end
    return gRows, aRows
end

-- ---------- analysis helpers ----------
local function shiftDiffX(gRows, W, H, shift)
    local total, cnt = 0, 0
    local rowStep = math.max(1, floorFn(H / 40))
    local xStep = math.max(1, floorFn((W - shift) / 500))
    for y = 1, H, rowStep do
        local s = gRows[y]
        for x = 1, W - shift, xStep do
            total = total + math.abs(byteFn(s, x) - byteFn(s, x + shift))
            cnt = cnt + 1
        end
    end
    return cnt > 0 and total / cnt or math.huge
end

local function shiftDiffY(gRows, W, H, shift)
    local total, cnt = 0, 0
    local colStep = math.max(1, floorFn(W / 48))
    local yStep = math.max(1, floorFn((H - shift) / 500))
    for y = 1, H - shift, yStep do
        local s1, s2 = gRows[y], gRows[y + shift]
        for x = 1, W, colStep do
            total = total + math.abs(byteFn(s1, x) - byteFn(s2, x))
            cnt = cnt + 1
        end
    end
    return cnt > 0 and total / cnt or math.huge
end

local MIN_CELL = 12

local function pickAxisCount(size, diffFn)
    -- Baseline: how different the sheet looks when shifted by amounts that
    -- do NOT line up with frames.
    local base, nb = 0, 0
    for _, f in ipairs({ 0.317, 0.433, 0.587 }) do
        local s = floorFn(size * f)
        if s >= 1 and s < size then
            base = base + diffFn(s)
            nb = nb + 1
        end
    end
    if nb == 0 then return 1 end
    base = base / nb

    local bestN, bestD = 1, math.huge
    for n = 2, 96 do
        if size % n == 0 and size / n >= MIN_CELL then
            local d = diffFn(size / n)
            if d < bestD - 1e-9 then bestN, bestD = n, d end
        end
    end
    -- Not clearly repeating => this axis has a single frame.
    if bestD < base * 0.6 then return bestN end
    return 1
end

local function cellIsEmpty(gRows, aRows, x0, y0, fw, fh)
    local minG, maxG, anyAlpha = 255, 0, false
    for j = 0, 7 do
        local y = y0 + floorFn((j + 0.5) * fh / 8) + 1
        for i = 0, 7 do
            local x = x0 + floorFn((i + 0.5) * fw / 8) + 1
            local g = byteFn(gRows[y], x)
            if g < minG then minG = g end
            if g > maxG then maxG = g end
            if aRows and byteFn(aRows[y], x) > 8 then anyAlpha = true end
        end
    end
    if aRows then return not anyAlpha end
    return (maxG - minG) <= 2
end

local function gridCachePath(path) return path .. ".grid" end

local function loadGridCache(path, W, H)
    local cp = gridCachePath(path)
    if not (isfile and readfile and isfile(cp)) then return nil end
    local ok, txt = pcall(readfile, cp)
    if not ok or type(txt) ~= "string" then return nil end
    local ver, w, h, c, r, f = txt:match("^(%w+),(%d+),(%d+),(%d+),(%d+),(%d+)$")
    if ver ~= "v1" then return nil end
    w, h, c, r, f = tonumber(w), tonumber(h), tonumber(c), tonumber(r), tonumber(f)
    if w ~= W or h ~= H or not c or c < 1 or not r or r < 1 then return nil end
    return { columns = c, rows = r, frames = f, frameWidth = W / c, frameHeight = H / r, source = "cache" }
end

local function saveGridCache(path, W, H, m)
    if not writefile then return end
    pcall(writefile, gridCachePath(path),
        ("v1,%d,%d,%d,%d,%d"):format(W, H, m.columns, m.rows, m.frames))
end

-- Returns { columns, rows, frames, frameWidth, frameHeight } or nil, reason
local function analyzeSpritesheet(path)
    if not readfile then return nil, "no readfile" end
    local okRead, data = pcall(readfile, path)
    if not okRead or type(data) ~= "string" then return nil, "cannot read file" end
    local info = pngInfoFromData(data)
    if not info then return nil, "not a PNG" end
    local W, H = info.width, info.height

    local cached = loadGridCache(path, W, H)
    if cached then return cached end

    if info.interlace ~= 0 then return nil, "interlaced PNG" end
    if info.bitDepth ~= 8 then return nil, "unsupported bit depth " .. info.bitDepth end
    if W * H > 16000000 then return nil, "sheet too large to analyze" end

    local okDec, gRows, aRows = pcall(decodePngRows, data, info)
    if not okDec then return nil, "decode failed: " .. tostring(gRows) end

    local C = pickAxisCount(W, function(s) return shiftDiffX(gRows, W, H, s) end)
    local R = pickAxisCount(H, function(s) return shiftDiffY(gRows, W, H, s) end)
    if C * R < 2 then return nil, "no repeating frames found" end

    local fw, fh = W / C, H / R
    local frames = C * R
    for idx = C * R - 1, 0, -1 do
        local col, row = idx % C, floorFn(idx / C)
        if cellIsEmpty(gRows, aRows, col * fw, row * fh, fw, fh) then
            frames = idx
        else
            break
        end
    end
    if frames < 2 then frames = C * R end

    local m = { columns = C, rows = R, frames = frames, frameWidth = fw, frameHeight = fh, source = "pixels" }
    saveGridCache(path, W, H, m)
    return m
end

local analysisMem, analysisBusy = {}, {}
local function analyzeSpritesheetShared(path)
    if analysisMem[path] ~= nil then return analysisMem[path] or nil end
    while analysisBusy[path] do task.wait(0.1) end
    if analysisMem[path] ~= nil then return analysisMem[path] or nil end
    analysisBusy[path] = true
    local ok, res, why = pcall(analyzeSpritesheet, path)
    analysisBusy[path] = nil
    if ok and res then
        analysisMem[path] = res
        return res
    end
    analysisMem[path] = false
    warn("[Prism] Could not analyze sheet pixels (" .. tostring(ok and why or res) .. "), using size-based guess.")
    return nil
end


-- ============================================================
-- AUTO GRID DETECTION
-- ============================================================
local function autoDetectGrid(imgW, imgH)
    local best, bestScore = nil, math.huge
    local colCandidates = {}
    for c = 1, 64 do
        if imgW % c == 0 then colCandidates[#colCandidates + 1] = c end
    end

    for _, cols in ipairs(colCandidates) do
        local fw = imgW / cols
        for rows = 1, 64 do
            if imgH % rows == 0 then
                local fh = imgH / rows
                local total = cols * rows
                if total >= 4 and total <= 1024 then
                    local aspect = math.max(fw, fh) / math.min(fw, fh)
                    -- Prefer square frames. Penalize very large total frame counts slightly.
                    local score = math.abs(math.log(aspect)) * 1000
                    if total > 256 then score = score + 500 end
                    if score < bestScore then
                        bestScore = score
                        best = { columns=cols, rows=rows, frameWidth=fw, frameHeight=fh }
                    end
                end
            end
        end
    end
    return best
end


-- ============================================================
-- FRAME URL LIST + GITHUB FOLDER
-- ============================================================
local function parseFrameUrlList(text)
    local urls = {}
    if type(text) ~= "string" or text == "" then return urls end
    for line in text:gmatch("[^\r\n]+") do
        local u = line:match("^%s*(.-)%s*$")
        if u and u:match("^https?://") then
            urls[#urls + 1] = u
        end
    end
    return urls
end

local function parseGithubFolderUrl(url)
    if type(url) ~= "string" then return nil end
    url = url:match("^%s*(.-)%s*$") or ""
    local owner, repo, branch, path = url:match(
        "^https?://github%.com/([^/]+)/([^/]+)/tree/([^/]+)/?(.*)$")
    if owner then
        path = path or ""
        path = path:gsub("/+$", "")
        return owner, repo:gsub("%.git$", ""), branch, path
    end
    return nil
end

local function fetchGithubFolderFrameUrls(folderUrl)
    local owner, repo, branch, path = parseGithubFolderUrl(folderUrl)
    if not owner then return {} end
    if not httprequest then return {} end

    local function sortAndReturn(entries)
        table.sort(entries, function(a, b) return tostring(a.name) < tostring(b.name) end)
        local out = {}
        for i = 1, #entries do out[i] = entries[i].url end
        return out
    end

    local function isImageName(name)
        local lower = tostring(name or ""):lower()
        return lower:match("%.png$") or lower:match("%.jpe?g$") or lower:match("%.webp$") or lower:match("%.gif$")
    end

    -- 1) GitHub Contents API (needs User-Agent; 403 = rate limit / blocked)
    do
        local apiPath = path ~= "" and path or ""
        local api = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(
            owner, repo, apiPath, branch)
        local ok, res = pcall(httprequest, {
            Url = api,
            Method = "GET",
            Headers = {
                ["Accept"] = "application/vnd.github+json",
                ["User-Agent"] = "PrismNametags/1.0",
            },
        })
        if ok and res then
            local status = res.StatusCode or res.status or 0
            local body = res.Body or res.body or ""
            if status >= 200 and status < 300 then
                local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, body)
                if decodeOk and type(data) == "table" then
                    local entries = {}
                    for _, item in ipairs(data) do
                        if type(item) == "table" and item.type == "file"
                            and type(item.download_url) == "string"
                            and isImageName(item.name)
                        then
                            entries[#entries + 1] = { name = item.name, url = item.download_url }
                        end
                    end
                    if #entries > 0 then
                        print(("[Prism] GitHub API listed %d frames"):format(#entries))
                        return sortAndReturn(entries)
                    end
                end
            else
                warn(("[Prism] GitHub API HTTP %s — falling back to page scrape"):format(tostring(status)))
            end
        end
    end

    -- 2) Scrape the public tree page HTML (no API rate limit)
    do
        local pageUrl = ("https://github.com/%s/%s/tree/%s/%s"):format(
            owner, repo, branch, path ~= "" and path or "")
        local ok, res = pcall(httprequest, {
            Url = pageUrl,
            Method = "GET",
            Headers = { ["User-Agent"] = "Mozilla/5.0 PrismNametags/1.0" },
        })
        if ok and res then
            local status = res.StatusCode or res.status or 0
            local body = res.Body or res.body or ""
            if status >= 200 and status < 300 and body ~= "" then
                local entries, seen = {}, {}
                -- Match filenames under this folder from the page / embedded JSON
                local folderPrefix = path ~= "" and (path .. "/") or ""
                for name in body:gmatch(folderPrefix:gsub("(%W)", "%%%1") .. "([%w%._%-]+%.[Pp][Nn][Gg])") do
                    if isImageName(name) and not seen[name] then
                        seen[name] = true
                        local raw = ("https://raw.githubusercontent.com/%s/%s/%s/%s%s"):format(
                            owner, repo, branch, folderPrefix, name)
                        entries[#entries + 1] = { name = name, url = raw }
                    end
                end
                -- Broader fallback: any frame_*.png on the page
                if #entries == 0 then
                    for name in body:gmatch("(frame_[%w%._%-]+%.[Pp][Nn][Gg])") do
                        if not seen[name] then
                            seen[name] = true
                            local raw = ("https://raw.githubusercontent.com/%s/%s/%s/%s%s"):format(
                                owner, repo, branch, folderPrefix, name)
                            entries[#entries + 1] = { name = name, url = raw }
                        end
                    end
                end
                if #entries > 0 then
                    print(("[Prism] GitHub page scrape listed %d frames"):format(#entries))
                    return sortAndReturn(entries)
                end
            end
        end
    end

    warn("[Prism] Could not list GitHub folder frames. Paste raw frame URLs into frame_urls instead.")
    return {}
end

local function downloadFrameAssets(userId, urls)
    local assets = {}
    if type(urls) ~= "table" then return assets end
    for i = 1, #urls do
        local path = downloadImageForUser(userId, urls[i])
        if path then
            local asset = getAsset(path)
            if asset then
                assets[#assets + 1] = asset
            end
        end
    end
    return assets
end

-- ============================================================
-- ROW -> CONFIG
-- ============================================================
local function buildConfigFromRow(userId, row)
    local imagePath = nil
    if row.background_image and row.background_image ~= "" then
        imagePath = downloadImageForUser(userId, row.background_image)
    end

    local spritesheetPath  = nil
    local spritesheetAsset = nil
    if row.spritesheet_url and row.spritesheet_url ~= "" then
        spritesheetPath = downloadImageForUser(userId, row.spritesheet_url)
        if spritesheetPath then spritesheetAsset = getAsset(spritesheetPath) end
    end

    local cols = tonumber(row.spritesheet_columns)
    local rows = tonumber(row.spritesheet_rows)
    local fw   = tonumber(row.spritesheet_frame_width)
    local fh   = tonumber(row.spritesheet_frame_height)

    local frames = tonumber(row.spritesheet_frames)

    -- Columns/rows left over from a previous sheet won't divide the new one.
    -- Ignore them so the grid is detected fresh instead of scrolling.
    if spritesheetPath and cols and rows then
        local info0 = getPngInfo(spritesheetPath)
        if info0 and (info0.width % cols ~= 0 or info0.height % rows ~= 0) then
            warn(("[Prism] Ignoring spritesheet_columns/rows (%dx%d): they don't fit this %dx%d sheet. " ..
                  "Detecting the grid automatically instead."):format(cols, rows, info0.width, info0.height))
            cols, rows = nil, nil
        end
    end

    -- Auto-detect if cols/rows are missing (typical: all four are NULL).
    -- Frame width/height are no longer needed for playback, only cols/rows.
    if spritesheetPath and (not cols or not rows) then
        local metaKey = tostring(spritesheetPath) .. "|" .. tostring(fw) .. "|" .. tostring(fh)
        local meta = spriteMetaCache[metaKey]
        if not meta then
            local info = getPngInfo(spritesheetPath)
            if info then
                if info.colorType == 3 then
                    warn(("[Prism] ⚠ Palette PNG (color type 3) may render incorrectly. " ..
                          "Re-export as RGB/RGBA (Image → Mode → RGB Color). " ..
                          "File: %s"):format(spritesheetPath))
                end
                if info.interlace == 1 then
                    warn("[Prism] ⚠ Interlaced PNG — re-export as non-interlaced. " ..
                          "File: " .. spritesheetPath)
                end

                local detected
                if fw and fh and fw > 0 and fh > 0 then
                    -- Frame size given in Supabase: derive the grid from it.
                    detected = {
                        columns = math.max(1, math.floor(info.width  / fw + 0.5)),
                        rows    = math.max(1, math.floor(info.height / fh + 0.5)),
                        frameWidth = fw, frameHeight = fh,
                    }
                else
                    -- Real detection from the image pixels, with the old
                    -- size-based guess only as a last resort.
                    detected = analyzeSpritesheetShared(spritesheetPath)
                             or autoDetectGrid(info.width, info.height)
                end
                if detected then
                    meta = detected
                    spriteMetaCache[metaKey] = meta
                    print(string.format(
                        "[Prism] Sheet %dx%d (colorType=%d) -> grid %dx%d, frame %.0fx%.0f, %d frames [%s]",
                        info.width, info.height, info.colorType,
                        meta.columns, meta.rows, meta.frameWidth, meta.frameHeight,
                        meta.frames or (meta.columns * meta.rows), meta.source or "size-guess"))
                else
                    warn("[Prism] Could not auto-detect grid. Sheet is " ..
                          info.width .. "x" .. info.height)
                end
            else
                warn("[Prism] Could not read PNG header from " .. tostring(spritesheetPath))
            end
        end
        if meta then
            if not frames and not cols and not rows then frames = meta.frames end
            cols = cols or meta.columns
            rows = rows or meta.rows
            fw   = fw   or meta.frameWidth
            fh   = fh   or meta.frameHeight
        end
    elseif spritesheetPath and cols and rows then
        local info = getPngInfo(spritesheetPath)
        if info and (info.width % cols ~= 0 or info.height % rows ~= 0) then
            warn(("[Prism] ⚠ spritesheet_columns/rows (%dx%d) don't divide this sheet (%dx%d). " ..
                  "They are probably left over from the previous sheet. " ..
                  "Clear them in Supabase to auto-detect, or set the correct values."):format(
                  cols, rows, info.width, info.height))
        end
        print(string.format("[Prism] Sheet (explicit): %dx%d grid", cols, rows))
    end

    -- ---- Reading-order fix ------------------------------------------
    -- Playback is row-major (left→right, then next row) — the GIF order.
    -- The pixel detector sometimes reports a wide strip as 1 column × N
    -- rows, which makes the animator slide the stretched sheet *down*
    -- the tag instead of advancing frames sideways (looks like it's
    -- "playing upward"). If the sheet's aspect ratio strongly disagrees
    -- with the detected grid's aspect ratio, transpose the grid so the
    -- frames run along the long axis — the same behaviour the cat.png
    -- link gets naturally.
    if spritesheetPath and cols and rows and cols > 0 and rows > 0 then
        local sinfo = getPngInfo(spritesheetPath)
        if sinfo and sinfo.width > 0 and sinfo.height > 0 then
            local gridAspect  = cols / rows
            local sheetAspect = sinfo.width / sinfo.height
            if sheetAspect >= 1.5 and gridAspect < 1 then
                cols, rows = rows, 1
                print(("[Prism] Transposed grid → %dx%d (wide sheet was read as a column)"):format(cols, rows))
            elseif sheetAspect <= (1 / 1.5) and gridAspect > 1 then
                cols, rows = 1, cols
                print(("[Prism] Transposed grid → %dx%d (tall sheet was read as a row)"):format(cols, rows))
            end
        end
    end
    -- -----------------------------------------------------------------

    -- ---- Fallback to static image if detection failed ---------------
    -- If we couldn't figure out the grid, show the sheet as a single
    -- static image instead of sliding a broken animation around.
    if spritesheetAsset and (not cols or not rows or cols < 1 or rows < 1) then
        warn("[Prism] Grid detection failed — displaying sheet as a static image.")
        cols, rows = 1, 1
        frames = 1
    end
    -- -----------------------------------------------------------------

    -- Clamp frames to the grid size
    if frames and cols and rows then
        local maxFrames = cols * rows
        if frames > maxFrames then frames = maxFrames end
        if frames < 1 then frames = maxFrames end
    end

    local spritesheetActive =
        spritesheetAsset ~= nil
        and cols and cols > 0
        and rows and rows > 0

    -- ---- Individual frame URLs (preferred over spritesheet when present) ----
    local frameAssets = {}
    local frameUrlList = parseFrameUrlList(row.frame_urls)
    if #frameUrlList == 0 and row.frame_folder and row.frame_folder ~= "" then
        frameUrlList = fetchGithubFolderFrameUrls(row.frame_folder)
        if #frameUrlList > 0 then
            print(("[Prism] GitHub folder yielded %d frame URLs"):format(#frameUrlList))
        end
    end
    if #frameUrlList > 0 then
        print(("[Prism] Downloading %d frame images for user %s..."):format(#frameUrlList, tostring(userId)))
        frameAssets = downloadFrameAssets(userId, frameUrlList)
        print(("[Prism] Loaded %d/%d frame assets for user %s"):format(#frameAssets, #frameUrlList, tostring(userId)))
    end
    local frameAnimActive = #frameAssets >= 2
    local frameTime = tonumber(row.frame_time) or 0.1
    if frameAnimActive then
        spritesheetActive = false
    end
    -- -----------------------------------------------------------------------

    return {
        userIds           = {},
        imagePath         = imagePath,
        borderColor       = hexToColor3(row.border_color),
        gradientColor     = hexToColor3(row.gradient_color),
        gradientSpinColor = hexToColor3(row.gradient_spin_color),
        bgColor           = hexToColor3(row.background_color),
        textColor         = hexToColor3(row.text_color),
        usernameColor     = hexToColor3(row.username_color),
        -- Overrides win when populated; otherwise the editable
        -- username/display_name values are used.
        displayNameText   = (row.display_name_override ~= nil and row.display_name_override ~= "" and row.display_name_override) or row.display_name,
        usernameText      = (row.username_override ~= nil and row.username_override ~= "" and row.username_override) or row.username,
        showDisplayName   = row.show_display_name ~= false,
        showUsername      = row.show_username ~= false,
        usernamePrefix    = row.username_prefix,
        typingText        = row.typing_text,
        distanceLabel     = row.distance_label,
        font              = safeFont(row.font, nil),
        textSize          = tonumber(row.text_size),
        usernameSize      = tonumber(row.username_size),
        width             = tonumber(row.nametag_width),
        height            = tonumber(row.nametag_height),
        isAnimated        = frameAnimActive,
        frameBasePath     = nil,
        frameCount        = #frameAssets,
        frameAssets       = frameAssets,
        frameTime         = frameTime,
        spritesheetUrl         = row.spritesheet_url,
        spritesheetAsset       = spritesheetAsset,
        spritesheetPath        = spritesheetPath,
        spritesheetColumns     = cols,
        spritesheetRows        = rows,
        spritesheetFrameWidth  = fw,
        spritesheetFrameHeight = fh,
        spritesheetFrameTime   = tonumber(row.spritesheet_frame_time) or 0.08,
        spritesheetFrames      = frames,
        spritesheetActive      = spritesheetActive and true or false,
        _fromSupabase = true,
    }
end

local function getNametagConfig(userId)
    userId = tonumber(userId)
    local row = remoteConfigs[userId]
    if row then
        if row.enabled == false then return nil end
        local sig = rowSignature(row)
        local cached = configCache[userId]
        if cached and cached.sig == sig then return cached.config end

        local cfg = buildConfigFromRow(userId, row)

        -- Only cache complete configs. If an image failed to download, retry
        -- next sync instead of freezing a broken config.
        local wantsSprite = row.spritesheet_url and row.spritesheet_url ~= ""
        local wantsImage  = row.background_image and row.background_image ~= ""
        local wantsFrames = (row.frame_urls and row.frame_urls ~= "")
                         or (row.frame_folder and row.frame_folder ~= "")
        local complete = (not wantsSprite or cfg.spritesheetActive or wantsFrames)
                     and (not wantsImage or cfg.imagePath ~= nil or wantsFrames)
                     and (not wantsFrames or (cfg.frameAssets and #cfg.frameAssets >= 1))
        if complete then configCache[userId] = { sig = sig, config = cfg } end
        return cfg
    end
    for _, config in pairs(PrismNametags.NAMETAG_CONFIG) do
        for _, id in ipairs(config.userIds or {}) do
            if id == userId then return config end
        end
    end
    return nil
end

local function fetchSupabaseConfigs()
    -- Fetch disabled rows too so a row can explicitly turn a player's
    -- nametag off. getNametagConfig() handles enabled=false.
    local data = supabaseGet(SUPABASE.tagsTable .. "?select=*")
    if not data or type(data) ~= "table" then return end
    local playerIds = {}
    for _, plr in ipairs(Players:GetPlayers()) do playerIds[plr.UserId] = true end
    local newMap = {}
    for _, row in ipairs(data) do
        local uid = tonumber(row.user_id)
        if uid and playerIds[uid] then newMap[uid] = row end
    end
    remoteConfigs = newMap
end

-- ============================================================
-- FILE DOWNLOAD
-- ============================================================
function PrismNametags.downloadFile(category, name)
    local file = PrismNametags.FileRegistry[category] and PrismNametags.FileRegistry[category][name]
    if not file then return false, "File not found in registry" end
    local success, imageData
    if httprequest then
        success, imageData = pcall(function()
            local response = httprequest({
                Url = file.url, Method = "GET",
                Headers = { ["Content-Type"] = "application/octet-stream" },
            })
            return response.Body or response
        end)
    else
        success, imageData = pcall(function() return game:HttpGet(file.url) end)
    end
    if not success or not imageData or imageData == "" then return false, imageData end
    local folderPath = file.path:match("^(.-)/[^/]+$")
    if folderPath and makefolder and not isfolder(folderPath) then makefolder(folderPath) end
    local successWrite = pcall(function() writefile(file.path, imageData) end)
    if not successWrite then return false, "Failed to write file" end
    return true, file.path
end

function PrismNametags.downloadAllFiles()
    for category, files in pairs(PrismNametags.FileRegistry) do
        for name, _ in pairs(files) do
            task.spawn(function() PrismNametags.downloadFile(category, name) end)
        end
    end
end

-- ============================================================
-- TYPING EFFECT
-- ============================================================
local typingEffectConnections = {}

local function stopTypingEffect(textLabel)
    if typingEffectConnections[textLabel] then
        for _, c in ipairs(typingEffectConnections[textLabel]) do c:Disconnect() end
        typingEffectConnections[textLabel] = nil
    end
end

local function startTypingEffect(textLabel, displayName, typingText)
    stopTypingEffect(textLabel)
    local connections = {}
    local targetText = displayName .. "  " .. (typingText or "Owner")
    local dotChar = "•"
    local visibleLength = 0
    local isHiding = false
    local showCursor = true
    local lastCursorToggle = tick()
    local lastUpdate = tick()
    local lastCycleStart = tick()
    local dotPosition = #displayName + 2

    local hb = RunService.Heartbeat:Connect(function()
        if not textLabel or not textLabel.Parent then return end
        local now = tick()
        if now - lastCursorToggle >= 0.5 then
            showCursor = not showCursor; lastCursorToggle = now
        end
        if now - lastCycleStart >= 5 then isHiding = true; lastCycleStart = now end
        if now - lastUpdate >= 0.05 then
            if isHiding then
                if visibleLength > 0 then visibleLength = visibleLength - 1
                else isHiding = false end
            else
                if visibleLength < #targetText then visibleLength = visibleLength + 1 end
            end
            lastUpdate = now
        end
        local displayText = targetText:sub(1, visibleLength)
        if not isHiding and visibleLength >= dotPosition then
            local beforeDot = displayText:sub(1, dotPosition - 1)
            local afterDot  = displayText:sub(dotPosition)
            displayText = beforeDot .. dotChar .. afterDot
        end
        textLabel.Text = displayText .. (showCursor and "|" or "")
    end)
    table.insert(connections, hb)
    typingEffectConnections[textLabel] = connections
end

-- ============================================================
-- SPRITESHEET ANIMATION (resolution-independent, position-based)
-- ============================================================
local spritesheetConnections = {}

local function stopSpritesheetAnimation(imageLabel)
    if spritesheetConnections[imageLabel] then
        spritesheetConnections[imageLabel]:Disconnect()
        spritesheetConnections[imageLabel] = nil
    end
end

local function startSpritesheetAnimation(imageLabel, config)
    stopSpritesheetAnimation(imageLabel)
    if not config or not config.spritesheetActive then return end

    local cols = math.floor(tonumber(config.spritesheetColumns) or 0)
    local rows = math.floor(tonumber(config.spritesheetRows) or 0)
    local ft   = tonumber(config.spritesheetFrameTime) or 0.08
    if cols < 1 or rows < 1 then
        warn("[Prism] Invalid spritesheet grid")
        return
    end
    if ft <= 0 then ft = 0.08 end

    local totalFrames = cols * rows
    local limit = math.floor(tonumber(config.spritesheetFrames) or 0)
    if limit >= 1 and limit < totalFrames then totalFrames = limit end  -- skip empty trailing cells

    -- imageLabel's parent (SpriteBackground) is the clipping window.
    -- The image is scaled to cols x rows window-sizes, so exactly one
    -- cell is visible. Moving Position selects the cell. No ImageRect is
    -- used, so Roblox's image downscaling can't shift anything.
    imageLabel.AnchorPoint = Vector2.zero
    imageLabel.Size = UDim2.fromScale(cols, rows)
    imageLabel.ScaleType = Enum.ScaleType.Stretch
    imageLabel.ImageRectOffset = Vector2.zero
    imageLabel.ImageRectSize = Vector2.zero   -- 0 = use whole image

    local current = 0
    local elapsed = 0

    -- Row-major playback: left→right, then down to the next row. This
    -- is the same order as a GIF and matches how the cat.png sheet is
    -- laid out. The reading-order transpose in buildConfigFromRow makes
    -- sure every sheet ends up with a wide (cols > rows) grid so this
    -- order lines up with the pixels.
    local function display(index)
        current = index % totalFrames
        local col = current % cols
        local row = math.floor(current / cols)
        imageLabel.Position = UDim2.fromScale(-col, -row)
    end

    display(0)

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if not imageLabel.Parent then
            connection:Disconnect()
            spritesheetConnections[imageLabel] = nil
            return
        end
        elapsed += dt
        if elapsed < ft then return end
        local steps = math.floor(elapsed / ft)
        elapsed -= steps * ft
        display(current + steps)
    end)
    spritesheetConnections[imageLabel] = connection
end

-- ============================================================
-- LEGACY FRAME ANIMATION
-- ============================================================
local frameAnimationConnections = {}
local frameLabelsRegistry       = {}

local function stopFrameAnimation(parentFrame)
    if frameAnimationConnections[parentFrame] then
        for _, c in ipairs(frameAnimationConnections[parentFrame]) do c:Disconnect() end
        frameAnimationConnections[parentFrame] = nil
    end
    local frameLabels = frameLabelsRegistry[parentFrame]
    if frameLabels then
        for _, fl in pairs(frameLabels) do pcall(function() fl:Destroy() end) end
        frameLabelsRegistry[parentFrame] = nil
    end
    if parentFrame and parentFrame.Parent then
        for _, child in ipairs(parentFrame:GetChildren()) do
            if child.Name:sub(1, 6) == "Frame_" then pcall(function() child:Destroy() end) end
        end
    end
end

local function startFrameAnimation(parentFrame, config)
    local labels = {} -- dense 1-based array of ImageLabels

    -- Preferred: pre-downloaded frame assets from Supabase frame_urls
    if type(config.frameAssets) == "table" and #config.frameAssets >= 1 then
        for i = 1, #config.frameAssets do
            local frameLabel = Instance.new("ImageLabel")
            frameLabel.Name = "Frame_" .. (i - 1)
            frameLabel.Size = UDim2.new(1, 0, 1, 0)
            frameLabel.BackgroundTransparency = 1
            frameLabel.Image = config.frameAssets[i]
            frameLabel.ScaleType = Enum.ScaleType.Stretch
            frameLabel.Visible = (i == 1)
            frameLabel.ZIndex = -1
            frameLabel.Parent = parentFrame
            local bgCorner = Instance.new("UICorner")
            bgCorner.CornerRadius = UDim.new(0, 8)
            bgCorner.Parent = frameLabel
            labels[#labels + 1] = frameLabel
        end
    elseif config.isAnimated and (config.frameCount or 0) > 1 and config.frameBasePath then
        local frameBasePath = config.frameBasePath or ""
        local frameCount = config.frameCount or 1
        for i = 0, frameCount - 1 do
            local framePath = frameBasePath .. i .. ".png"
            if isfile and isfile(framePath) then
                local frameAsset = getAsset(framePath)
                if frameAsset then
                    local frameLabel = Instance.new("ImageLabel")
                    frameLabel.Name = "Frame_" .. i
                    frameLabel.Size = UDim2.new(1, 0, 1, 0)
                    frameLabel.BackgroundTransparency = 1
                    frameLabel.Image = frameAsset
                    frameLabel.ScaleType = Enum.ScaleType.Stretch
                    frameLabel.Visible = (#labels == 0)
                    frameLabel.ZIndex = -1
                    frameLabel.Parent = parentFrame
                    local bgCorner = Instance.new("UICorner")
                    bgCorner.CornerRadius = UDim.new(0, 8)
                    bgCorner.Parent = frameLabel
                    labels[#labels + 1] = frameLabel
                end
            end
        end
    end

    if #labels == 0 then return end
    local registry = {}
    for i = 1, #labels do registry[i - 1] = labels[i] end
    frameLabelsRegistry[parentFrame] = registry

    if #labels == 1 then return end

    local currentFrame    = 1
    local lastFrameUpdate = tick()
    local frameTime       = config.frameTime or 0.1
    local frameCount      = #labels

    local hb = RunService.Heartbeat:Connect(function()
        if not parentFrame or not parentFrame.Parent then return end
        local now = tick()
        if now - lastFrameUpdate >= frameTime then
            labels[currentFrame].Visible = false
            currentFrame = currentFrame % frameCount + 1
            lastFrameUpdate = now
            labels[currentFrame].Visible = true
        end
    end)
    frameAnimationConnections[parentFrame] = { hb }
end

local function cleanupBillboardEffects(billboard)
    if not billboard then return end
    local tagFrame = billboard:FindFirstChild("TagFrame")
    if not tagFrame then return end
    local dn = tagFrame:FindFirstChild("DisplayName")
    if dn then stopTypingEffect(dn) end
    if frameAnimationConnections[tagFrame] then stopFrameAnimation(tagFrame) end
    for _, child in ipairs(tagFrame:GetDescendants()) do
        if child:IsA("ImageLabel") then
            stopSpritesheetAnimation(child)
        end
    end
end

-- ============================================================
-- STATE
-- ============================================================
local nametagEnabled       = true
local nametagGui           = nil
local nametagConnection    = nil
local otherNametags        = {}
local autoSyncEnabled      = true
local originalDisplayTypes = {}
local characterAddedConns  = {}

-- Billboards are parented to PlayerGui (not the head), so any leftover copy
-- must be found there. Orphaned copies were the "old gif comes back" bug.
local function purgeTagsByName(name)
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, child in ipairs(pg:GetChildren()) do
        if child.Name == name then
            cleanupBillboardEffects(child)
            pcall(function() child:Destroy() end)
        end
    end
end

-- ============================================================
-- CLEAR
-- ============================================================
function PrismNametags.clearAllNametags()
    local player    = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")

    for textLabel in pairs(typingEffectConnections) do stopTypingEffect(textLabel) end
    for imageLabel in pairs(frameAnimationConnections) do stopFrameAnimation(imageLabel) end
    for imageLabel in pairs(spritesheetConnections)  do stopSpritesheetAnimation(imageLabel) end

    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name == "PrismNametag" or child.Name:sub(1, 13) == "PrismNametag_" then
                cleanupBillboardEffects(child); pcall(function() child:Destroy() end)
            end
        end
    end
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            for _, child in ipairs(head:GetChildren()) do
                if child.Name == "PrismNametag" then
                    cleanupBillboardEffects(child); pcall(function() child:Destroy() end)
                end
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                for _, child in ipairs(head:GetChildren()) do
                    if child.Name:sub(1, 13) == "PrismNametag_" then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
    for _, tagData in pairs(otherNametags) do
        if tagData.connection then tagData.connection:Disconnect() end
    end
    otherNametags = {}
    if nametagConnection then nametagConnection:Disconnect(); nametagConnection = nil end
    nametagGui = nil
end

-- ============================================================
-- SHARED BILLBOARD BUILDER
-- ============================================================
local function buildPrismBillboard(player, config, head, isSelf)
    local hasCustomTag =
        config ~= nil and (
            config.imagePath ~= nil
            or config.spritesheetActive == true
            or config.isAnimated == true
        )

    local userBgColor           = config and config.bgColor or nil
    local userBorderColor       = (config and config.borderColor) or C.sep
    local userGradientColor     = config and config.gradientColor or nil
    local userGradientSpinColor = config and config.gradientSpinColor or nil

    local width  = (config and config.width)  or 150
    local height = (config and config.height) or 50

    local billboard = Instance.new("BillboardGui")
    billboard.Name = isSelf and "PrismNametag" or ("PrismNametag_" .. player.UserId)
    billboard.Size = UDim2.new(0, width, 0, height)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 9999
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.ClipsDescendants = false
    billboard.ResetOnSpawn = false
    if not isSelf then billboard.Active = true end
    billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BgFrame"
    bgFrame.Size = UDim2.new(1, 4, 1, 4)
    bgFrame.Position = UDim2.new(0, -2, 0, -2)
    bgFrame.BackgroundColor3 = userBorderColor
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame

    local bgGradient = Instance.new("UIGradient")
    if hasCustomTag and userGradientColor and userGradientSpinColor then
        bgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    userGradientSpinColor),
            ColorSequenceKeypoint.new(0.25, userGradientColor),
            ColorSequenceKeypoint.new(0.5,  userGradientSpinColor),
            ColorSequenceKeypoint.new(0.75, userGradientColor),
            ColorSequenceKeypoint.new(1,    userGradientSpinColor),
        })
    else
        bgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(0.25, C.sep),
            ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(20,20,20)),
            ColorSequenceKeypoint.new(0.75, C.sep),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(255,255,255)),
        })
    end
    bgGradient.Parent = bgFrame

    local frame = Instance.new("Frame")
    frame.Name = "TagFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = userBgColor or C.card
    frame.BackgroundTransparency =
        (userBgColor and 1)
        or (hasCustomTag and (config.spritesheetActive or config.isAnimated) and 1)
        or 0.1
    frame.BorderSizePixel = 0
    if not isSelf then frame.Active = true end
    frame.ClipsDescendants = true     -- ensures UICorner rounds the children
    frame.Parent = billboard

    if config and config.spritesheetActive then
        -- SpriteBackground is the fixed, rounded, clipping window the size of
        -- the tag. The ImageLabel inside is scaled to cols x rows windows and
        -- slid around by startSpritesheetAnimation, so only one cell shows.
        -- IMPORTANT: this must be a CanvasGroup. A normal Frame's
        -- ClipsDescendants only clips to a plain rectangle and ignores
        -- UICorner, so the oversized sheet showed square corners.
        -- CanvasGroup + UICorner clips its children to the rounded shape.
        local spriteBackground = Instance.new("CanvasGroup")
        spriteBackground.GroupTransparency = 0
        spriteBackground.Name = "SpriteBackground"
        spriteBackground.Size = UDim2.new(1, 0, 1, 0)
        spriteBackground.Position = UDim2.new(0, 0, 0, 0)
        spriteBackground.BackgroundTransparency = 1
        spriteBackground.BorderSizePixel = 0
        spriteBackground.ClipsDescendants = true
        spriteBackground.ZIndex = 0
        spriteBackground.Parent = frame

        local spriteCorner = Instance.new("UICorner")
        spriteCorner.CornerRadius = UDim.new(0, 8)
        spriteCorner.Parent = spriteBackground

        local bgImage = Instance.new("ImageLabel")
        bgImage.Name = "BgImage"
        bgImage.Size = UDim2.new(1, 0, 1, 0)   -- resized by the animator
        bgImage.Position = UDim2.new(0, 0, 0, 0)
        bgImage.BackgroundTransparency = 1
        bgImage.BorderSizePixel = 0
        bgImage.Image = config.spritesheetAsset
        bgImage.ImageTransparency = 0
        bgImage.ScaleType = Enum.ScaleType.Stretch
        bgImage.ZIndex = 0
        -- No UICorner here: the image is larger than the tag, and
        -- SpriteBackground already rounds and clips it.
        bgImage.Parent = spriteBackground

        startSpritesheetAnimation(bgImage, config)

    elseif config and ((config.frameAssets and #config.frameAssets >= 1) or (config.isAnimated and config.frameBasePath)) then
        startFrameAnimation(frame, config)

    elseif config and config.imagePath and isfile and isfile(config.imagePath) then
        local customAsset = getAsset(config.imagePath)
        if customAsset then
            local bgImage = Instance.new("ImageLabel")
            bgImage.Name = "BgImage"
            bgImage.Size = UDim2.new(1, 0, 1, 0)
            bgImage.BackgroundTransparency = 1
            bgImage.Image = customAsset
            bgImage.ScaleType = Enum.ScaleType.Stretch
            bgImage.ZIndex = -1
            bgImage.Parent = frame
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 8)
            bc.Parent = bgImage
        end
    end

    local tagCorner = Instance.new("UICorner")
    tagCorner.CornerRadius = UDim.new(0, 8)
    tagCorner.Parent = frame

    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Size = UDim2.new(1, -10, 0, 20)
    displayNameLabel.Position = UDim2.new(0, 5, 0, 5)
    displayNameLabel.BackgroundTransparency = 1
    local showDisplayName = not (config and config.showDisplayName == false)
    local nameText = (config and config.displayNameText) or player.DisplayName
    local hasTyping = showDisplayName and config and config.typingText and config.typingText ~= ""
    displayNameLabel.Text = hasTyping and "" or nameText
    displayNameLabel.Visible = showDisplayName
    displayNameLabel.TextColor3 = (config and config.textColor) or C.text
    displayNameLabel.TextSize   = (config and config.textSize) or 14
    displayNameLabel.Font       = (config and config.font) or Enum.Font.GothamBold
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayNameLabel.ZIndex = 2
    displayNameLabel.Parent = frame

    if hasTyping then
        startTypingEffect(displayNameLabel, nameText, config.typingText)
    end

    local showUsername = not (config and config.showUsername == false)
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    -- If display name is hidden, move the username into its old space.
    usernameLabel.Position = UDim2.new(0, 5, 0, showDisplayName and 25 or 5)
    usernameLabel.BackgroundTransparency = 1
    local unameText = (config and config.usernameText)
    if unameText and unameText ~= "" then
        if unameText:sub(1,1) ~= "@" then unameText = "@" .. unameText end
    else
        unameText = ((config and config.usernamePrefix) or "@ ") .. player.Name
    end
    usernameLabel.Text = unameText
    usernameLabel.TextColor3 = (config and config.usernameColor) or (hasCustomTag and C.text or C.textDim)
    usernameLabel.TextSize   = (config and config.usernameSize) or 11
    usernameLabel.Font       = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Visible    = showUsername
    usernameLabel.ZIndex     = 2
    usernameLabel.Parent = frame

    local smallLabel = Instance.new("TextLabel")
    smallLabel.Name = "SmallLabel"
    smallLabel.Size = UDim2.new(1, 0, 1, 0)
    smallLabel.BackgroundTransparency = 1
    smallLabel.Text = (config and config.distanceLabel) or "P"
    smallLabel.TextColor3 = (config and config.textColor) or C.text
    smallLabel.TextSize = 20
    smallLabel.Font = Enum.Font.GothamBold
    smallLabel.TextXAlignment = Enum.TextXAlignment.Center
    smallLabel.TextYAlignment = Enum.TextYAlignment.Center
    smallLabel.Visible = false
    smallLabel.ZIndex = 2
    smallLabel.Parent = frame

    return billboard, bgGradient, frame, displayNameLabel, usernameLabel, smallLabel, width, height
end

-- ============================================================
-- SELF NAMETAG
-- ============================================================
function PrismNametags.removeNametag()
    if nametagGui then
        cleanupBillboardEffects(nametagGui)
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
    if nametagConnection then nametagConnection:Disconnect(); nametagConnection = nil end
    if Players.LocalPlayer then appliedSignatures[Players.LocalPlayer.UserId] = nil end
end

local creatingSelf = false
function PrismNametags.createNametag()
    -- Lock: a rebuild can yield (HTTP). Without this, the 3s sync loop and
    -- CharacterAdded could run two builds at once and leave a stray copy.
    if creatingSelf then return end
    creatingSelf = true
    local ok, err = pcall(PrismNametags._createNametag)
    creatingSelf = false
    if not ok then warn("[Prism] createNametag failed: " .. tostring(err)) end
end

function PrismNametags._createNametag()
    local player = Players.LocalPlayer
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end

    -- Get the config FIRST (may yield), then swap old for new with no gap.
    local config = getNametagConfig(player.UserId)
    head = player.Character and player.Character:FindFirstChild("Head")
    if not head then return end

    PrismNametags.removeNametag()
    purgeTagsByName("PrismNametag")
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag" then pcall(function() child:Destroy() end) end
    end

    if not config then
        -- No enabled Supabase config for this player: do not create a Prism
        -- nametag. Restore Roblox's normal name display instead.
        nametagGui = nil
        appliedSignatures[player.UserId] = rowSignature(remoteConfigs[player.UserId])
        PrismNametags.restoreDefaultNametag(player)
        return
    end

    local bb, bgGradient = buildPrismBillboard(player, config, head, true)
    nametagGui = bb
    appliedSignatures[player.UserId] = rowSignature(remoteConfigs[player.UserId])

    nametagConnection = RunService.Heartbeat:Connect(function(dt)
        if not bb or not bb.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        local currentHead = player.Character and player.Character:FindFirstChild("Head")
        if currentHead then
            bb.Adornee = currentHead
            bb.Enabled = nametagEnabled
        else
            bb.Enabled = false
        end
    end)
end

-- ============================================================
-- OTHER PLAYERS
-- ============================================================
function PrismNametags.removeOtherNametag(userId)
    local entry = otherNametags[userId]
    if entry then
        if entry.gui then
            cleanupBillboardEffects(entry.gui)
            pcall(function() entry.gui:Destroy() end)
        end
        if entry.connection then entry.connection:Disconnect() end
        otherNametags[userId] = nil
    end
    appliedSignatures[userId] = nil
    local plr = Players:GetPlayerByUserId(userId)
    if plr then PrismNametags.restoreDefaultNametag(plr) end
end

local creatingOther = {}
function PrismNametags.createOtherNametag(plrObj)
    if creatingOther[plrObj.UserId] then return end
    creatingOther[plrObj.UserId] = true
    local ok, err = pcall(PrismNametags._createOtherNametag, plrObj)
    creatingOther[plrObj.UserId] = nil
    if not ok then warn("[Prism] createOtherNametag failed: " .. tostring(err)) end
end

function PrismNametags._createOtherNametag(plrObj)
    if not plrObj.Character then return end
    local head = plrObj.Character:FindFirstChild("Head")
    if not head then return end

    -- Get the config FIRST (may yield), then swap old for new with no gap.
    local config = getNametagConfig(plrObj.UserId)
    head = plrObj.Character and plrObj.Character:FindFirstChild("Head")
    if not head then return end

    if otherNametags[plrObj.UserId] then
        PrismNametags.removeOtherNametag(plrObj.UserId)
    end
    purgeTagsByName("PrismNametag_" .. plrObj.UserId)
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag_" .. plrObj.UserId then
            pcall(function() child:Destroy() end)
        end
    end

    local bb, bgGradient, frame, dn, un, sl, width, height =
        buildPrismBillboard(plrObj, config, head, false)

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local myChar = Players.LocalPlayer.Character
            local targetChar = plrObj.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                local myHRP = myChar.HumanoidRootPart
                local targetHRP = targetChar.HumanoidRootPart
                local behind = targetHRP.CFrame * CFrame.new(0, 0, 3)
                myHRP.CFrame = CFrame.new(behind.Position, behind.Position + targetHRP.CFrame.LookVector)
            end
        end
    end)

    local connection = RunService.Heartbeat:Connect(function(dt)
        if not bb or not bb.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        local targetHead = plrObj.Character and plrObj.Character:FindFirstChild("Head")
        if targetHead then
            bb.Adornee = targetHead
            bb.Enabled = nametagEnabled
        else
            bb.Enabled = false
            return
        end
        local myChar = Players.LocalPlayer.Character
        local targetChar = plrObj.Character
        if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
            local dist = (myChar.HumanoidRootPart.Position - targetChar.HumanoidRootPart.Position).Magnitude
            local isFar = dist > 50
            dn.Visible = not isFar
            un.Visible = not isFar and un.Text ~= ""
            sl.Visible = isFar
            if isFar then
                tween(bb, 0.1, { Size = UDim2.new(0, 40, 0, 40) })
            else
                tween(bb, 0.1, { Size = UDim2.new(0, width, 0, height) })
            end
        end
    end)

    otherNametags[plrObj.UserId] = { gui = bb, connection = connection }
    appliedSignatures[plrObj.UserId] = rowSignature(remoteConfigs[plrObj.UserId])

    if nametagEnabled then PrismNametags.hideDefaultNametag(plrObj) end
end

-- ============================================================
-- DEFAULT HIDE / TOGGLE
-- ============================================================
function PrismNametags.hideDefaultNametag(plr)
    if not plr.Character then return end
    local humanoid = plr.Character:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        originalDisplayTypes[plr.UserId] = humanoid.DisplayDistanceType
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
end

function PrismNametags.restoreDefaultNametag(plr)
    if not plr.Character then return end
    local humanoid = plr.Character:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = originalDisplayTypes[plr.UserId] or Enum.HumanoidDisplayDistanceType.Viewer
        originalDisplayTypes[plr.UserId] = nil
    end
end

function PrismNametags.toggle()
    nametagEnabled = not nametagEnabled
    if nametagEnabled then
        if nametagGui then nametagGui.Enabled = true else PrismNametags.createNametag() end
        for _, tagData in pairs(otherNametags) do
            if tagData.gui then tagData.gui.Enabled = true end
        end
        PrismNametags.hideDefaultNametag(Players.LocalPlayer)
        for userId, _ in pairs(otherNametags) do
            local plr = Players:GetPlayerByUserId(userId)
            if plr then PrismNametags.hideDefaultNametag(plr) end
        end
    else
        if nametagGui then nametagGui.Enabled = false end
        for _, tagData in pairs(otherNametags) do
            if tagData.gui then tagData.gui.Enabled = false end
        end
        PrismNametags.restoreDefaultNametag(Players.LocalPlayer)
        for userId, _ in pairs(otherNametags) do
            local plr = Players:GetPlayerByUserId(userId)
            if plr then PrismNametags.restoreDefaultNametag(plr) end
        end
    end
    return nametagEnabled
end

function PrismNametags.isEnabled() return nametagEnabled end

-- ============================================================
-- UPDATE OTHERS
-- ============================================================
function PrismNametags.updateOtherNametags()
    local myUserId = Players.LocalPlayer.UserId
    for _, plrObj in ipairs(Players:GetPlayers()) do
        if plrObj.UserId ~= myUserId then
            local row      = remoteConfigs[plrObj.UserId]
            local config   = getNametagConfig(plrObj.UserId)
            local sig      = rowSignature(row)
            local existing = otherNametags[plrObj.UserId]

            if config then
                if not existing then
                    if plrObj.Character and plrObj.Character:FindFirstChild("Head") then
                        PrismNametags.createOtherNametag(plrObj)
                    end
                elseif appliedSignatures[plrObj.UserId] ~= sig then
                    PrismNametags.createOtherNametag(plrObj)
                end
            elseif existing then
                PrismNametags.removeOtherNametag(plrObj.UserId)
            end
        end
    end

    local currentPlayers = {}
    for _, plrObj in ipairs(Players:GetPlayers()) do currentPlayers[plrObj.UserId] = true end
    for userId in pairs(otherNametags) do
        if not currentPlayers[userId] then
            PrismNametags.removeOtherNametag(userId)
        end
    end
end

-- ============================================================
-- USER INFO
-- ============================================================
local function getUserInfo()
    local player = Players.LocalPlayer
    if not player then return nil end
    local gameName = "Unknown"
    pcall(function()
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        if ok and info then gameName = info.Name or "Unknown" end
    end)
    return {
        user_id      = player.UserId,
        username     = player.Name,
        display_name = player.DisplayName or player.Name,
        job_id       = game.JobId,
        game_name    = gameName,
        last_seen    = DateTime.now():ToIsoDate(),
    }
end

-- ============================================================
-- CLEANUP
-- ============================================================
function PrismNametags.cleanup()
    for textLabel in pairs(typingEffectConnections) do stopTypingEffect(textLabel) end
    for imageLabel in pairs(frameAnimationConnections) do stopFrameAnimation(imageLabel) end
    for imageLabel in pairs(spritesheetConnections)  do stopSpritesheetAnimation(imageLabel) end

    autoSyncEnabled = false
    PrismNametags.restoreDefaultNametag(Players.LocalPlayer)
    for userId, _ in pairs(otherNametags) do
        local plr = Players:GetPlayerByUserId(userId)
        if plr then PrismNametags.restoreDefaultNametag(plr) end
    end
    PrismNametags.clearAllNametags()
    local player = Players.LocalPlayer
    if player then task.spawn(function() deleteUserRow(player.UserId) end) end
    nametagGui = nil
    nametagEnabled = false
    originalDisplayTypes = {}
    for uid, c in pairs(characterAddedConns) do
        pcall(function() c:Disconnect() end)
        characterAddedConns[uid] = nil
    end
end

local function setupPlayerCharacterHandler(plr)
    if characterAddedConns[plr.UserId] then
        pcall(function() characterAddedConns[plr.UserId]:Disconnect() end)
    end
    characterAddedConns[plr.UserId] = plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if plr == Players.LocalPlayer then
            PrismNametags.createNametag()
            if nametagEnabled and nametagGui then PrismNametags.hideDefaultNametag(plr) end
        else
            if getNametagConfig(plr.UserId) then
                PrismNametags.createOtherNametag(plr)
                if nametagEnabled then PrismNametags.hideDefaultNametag(plr) end
            end
        end
    end)
end

-- ============================================================
-- INITIALIZE
-- ============================================================
function PrismNametags.initialize()
    local player = Players.LocalPlayer

    PrismNametags.clearAllNametags()

    local info = getUserInfo()
    if info then
        registerUser(info.user_id, info.username, info.display_name, info.job_id, info.game_name)
        ensureNametagRow(info.user_id, info.username, info.display_name)
    end

    task.wait(0.6)
    fetchSupabaseConfigs()

    if player.Character and player.Character:FindFirstChild("Head") then
        PrismNametags.createNametag()
        if nametagEnabled and nametagGui then PrismNametags.hideDefaultNametag(player) end
    else
        player.CharacterAdded:Once(function()
            task.wait(0.5)
            PrismNametags.createNametag()
            if nametagEnabled and nametagGui then PrismNametags.hideDefaultNametag(player) end
        end)
    end

    PrismNametags.updateOtherNametags()

    for _, plr in ipairs(Players:GetPlayers()) do
        setupPlayerCharacterHandler(plr)
    end

    Players.PlayerAdded:Connect(function(plr)
        setupPlayerCharacterHandler(plr)
        task.wait(1.5)
        pcall(fetchSupabaseConfigs)
        if getNametagConfig(plr.UserId) then
            if plr.Character and plr.Character:FindFirstChild("Head") then
                PrismNametags.createOtherNametag(plr)
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(leavingPlayer)
        if characterAddedConns[leavingPlayer.UserId] then
            pcall(function() characterAddedConns[leavingPlayer.UserId]:Disconnect() end)
            characterAddedConns[leavingPlayer.UserId] = nil
        end
        PrismNametags.removeOtherNametag(leavingPlayer.UserId)
    end)

    task.spawn(function()
        while autoSyncEnabled do
            task.wait(SUPABASE.autoSyncInterval)
            local i = getUserInfo()
            if i then
                pcall(function()
                    registerUser(i.user_id, i.username, i.display_name, i.job_id, i.game_name)
                    ensureNametagRow(i.user_id, i.username, i.display_name)
                end)
            end
        end
    end)

    task.spawn(function()
        while autoSyncEnabled do
            task.wait(SUPABASE.autoSyncInterval)
            if not autoSyncEnabled then break end
            pcall(function()
                fetchSupabaseConfigs()
                local mySig = rowSignature(remoteConfigs[player.UserId])
                if appliedSignatures[player.UserId] ~= mySig or not nametagGui then
                    PrismNametags.createNametag()
                end
                PrismNametags.updateOtherNametags()
            end)
        end
    end)
end

task.spawn(function() PrismNametags.downloadAllFiles() end)

repeat task.wait() until Players.LocalPlayer
PrismNametags.initialize()

getgenv().PrismNametags = PrismNametags
return PrismNametags
